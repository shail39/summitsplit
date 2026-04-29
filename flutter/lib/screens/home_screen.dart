import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../main.dart' show themeNotifier;
import '../models/models.dart';
import '../services/user_profile.dart';

class _TripSummary {
  final Trip trip;
  final int memberCount;
  final int expenseCount;
  final double totalSpent;
  final double? myBalance; // null if no identity set
  final String? myName;

  _TripSummary({
    required this.trip,
    required this.memberCount,
    required this.expenseCount,
    required this.totalSpent,
    this.myBalance,
    this.myName,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<_TripSummary> _myTrips = [];
  bool _loading = true;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMyTrips();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfile.load();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _loadMyTrips() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('visited_trips') ?? [];
    final summaries = <_TripSummary>[];

    for (final id in ids) {
      try {
        final results = await Future.wait([
          ApiClient.getTrip(id),
          ApiClient.getMembers(id),
          ApiClient.getExpenses(id),
          ApiClient.getBalances(id),
        ]);
        final trip = results[0] as Trip;
        final members = results[1] as List<Member>;
        final expenses = results[2] as List<Expense>;
        final balances = results[3] as List<Balance>;
        final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);

        // Check if user has an identity for this trip
        final myId = prefs.getString('identity_$id');
        double? myBalance;
        String? myName;
        if (myId != null) {
          for (final b in balances) {
            if (b.member.id == myId) {
              myBalance = b.netBalance;
              myName = b.member.name;
              break;
            }
          }
        }

        summaries.add(_TripSummary(
          trip: trip,
          memberCount: members.length,
          expenseCount: expenses.length,
          totalSpent: totalSpent,
          myBalance: myBalance,
          myName: myName,
        ));
      } catch (_) {
        // Trip may have been deleted — skip
      }
    }

    if (mounted) {
      setState(() {
        _myTrips = summaries;
        _loading = false;
      });
    }
  }

  Future<void> _removeTrip(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('visited_trips') ?? [];
    ids.remove(tripId);
    await prefs.setStringList('visited_trips', ids);
    setState(() => _myTrips.removeWhere((t) => t.trip.id == tripId));
  }

  @override
  Widget build(BuildContext context) {
    final hasTrips = _myTrips.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summit Split'),
        actions: [
          if (_profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: _showProfileDialog,
                child: Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(_profile!.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366f1), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  label: Text(_profile!.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: Colors.white24,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              themeNotifier.mode == ThemeMode.dark ? Icons.dark_mode
                : themeNotifier.mode == ThemeMode.light ? Icons.light_mode
                : Icons.brightness_auto,
            ),
            tooltip: 'Toggle theme',
            onPressed: () => setState(() => themeNotifier.cycle()),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (!hasTrips) ...[
                      const SizedBox(height: 40),
                      const Text(
                        'Split trip expenses,\nsettle up fairly.',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a group and share the link — anyone with it can join.',
                        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 40),
                    ],

                    // My Trips
                    if (hasTrips) ...[
                      Row(children: [
                        const Text('My Trips', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _showCreateDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New'),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      ..._myTrips.map((s) => _TripCard(
                            summary: s,
                            onTap: () => context.go('/trips/${s.trip.id}'),
                            onRemove: () => _removeTrip(s.trip.id),
                          )),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => _showJoinDialog(context),
                        icon: const Icon(Icons.link),
                        label: const Text('Join a Trip'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF6366f1)),
                        ),
                      ),
                    ] else ...[
                      _ActionCard(
                        icon: Icons.add_circle_outline,
                        title: 'Start a new trip',
                        subtitle: 'Create a group and invite your crew.',
                        buttonLabel: '+ New Trip',
                        onTap: () => _showCreateDialog(context),
                      ),
                      const SizedBox(height: 16),
                      _ActionCard(
                        icon: Icons.link,
                        title: 'Join an existing trip',
                        subtitle: 'Paste the invite link or enter the trip code.',
                        buttonLabel: 'Join Trip',
                        onTap: () => _showJoinDialog(context),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  void _showProfileDialog() {
    final nameCtrl = TextEditingController(text: _profile?.name ?? '');
    final emailCtrl = TextEditingController(text: _profile?.email ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim().toLowerCase();
              if (name.isEmpty || email.isEmpty) return;
              await UserProfile.save(name, email);
              Navigator.pop(ctx);
              _loadProfile();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static const _tripEmojis = [
    '\u{26F0}', '\u{1F3D4}', '\u{1F3D6}', '\u{1F3DD}', '\u{1F30D}', '\u{2708}',
    '\u{1F697}', '\u{1F6F3}', '\u{1F3D5}', '\u{1F3E0}', '\u{1F37D}', '\u{1F389}',
    '\u{1F3C4}', '\u{26F7}', '\u{1F6B6}', '\u{1F3DB}', '\u{1F3A4}', '\u{1F3AC}',
    '\u{26FA}', '\u{1F3F0}', '\u{1F30A}', '\u{2B50}', '\u{1F525}', '\u{1F334}',
    '\u{1F3E8}', '\u{1F682}', '\u{1F6B2}', '\u{26F5}', '\u{1F3CA}', '\u{26F3}',
    '\u{1F3A8}', '\u{1F3B6}', '\u{2764}', '\u{1F4B0}', '\u{1F393}', '\u{1F3C6}',
  ];

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String currency = 'USD';
    String selectedEmoji = _tripEmojis[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Trip'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Trip name *'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: ['USD', 'EUR', 'GBP', 'INR', 'CAD', 'AUD']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => currency = v!),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Trip icon', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tripEmojis.map((e) => GestureDetector(
                      onTap: () => setDialogState(() => selectedEmoji = e),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selectedEmoji == e
                              ? const Color(0xFF6366f1).withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: selectedEmoji == e
                              ? Border.all(color: const Color(0xFF6366f1), width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 18)),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final trip = await ApiClient.createTrip(
                    nameCtrl.text.trim(), descCtrl.text.trim(), currency, emoji: selectedEmoji);
                  // Auto-add creator as first member
                  final profile = await UserProfile.load();
                  if (profile != null) {
                    final member = await ApiClient.addMember(trip.id, profile.name, profile.email);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('identity_${trip.id}', member.id);
                  }
                  if (context.mounted) context.go('/trips/${trip.id}');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a Trip'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Paste link or trip code',
            hintText: 'https://app.summitsplit.com/trips/...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              String code = ctrl.text.trim();
              final idx = code.lastIndexOf('/trips/');
              if (idx != -1) code = code.substring(idx + 7).split('?')[0].split('#')[0];
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.getTrip(code);
                if (context.mounted) context.go('/trips/$code');
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trip not found. Check the link.')));
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

// ── Trip Card with history ────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final _TripSummary summary;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _TripCard({required this.summary, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final balanceColor = (s.myBalance ?? 0) > 0.005
        ? const Color(0xFF6366f1)
        : (s.myBalance ?? 0) < -0.005
            ? Colors.red[600]!
            : Colors.grey[600]!;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF6366f1).withValues(alpha: 0.12),
                child: Text(
                  s.trip.emoji.isNotEmpty ? s.trip.emoji : '\u{26F0}',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.trip.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  if (s.trip.description.isNotEmpty)
                    Text(s.trip.description, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                onSelected: (v) {
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'remove', child: Row(children: [
                    Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remove from list', style: TextStyle(color: Colors.red)),
                  ])),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            // Stats row
            Row(children: [
              _Stat(icon: Icons.people_outline, label: '${s.memberCount} members'),
              const SizedBox(width: 16),
              _Stat(icon: Icons.receipt_long_outlined, label: '${s.expenseCount} expenses'),
              const SizedBox(width: 16),
              _Stat(icon: Icons.payments_outlined, label: '${s.trip.currency} ${s.totalSpent.toStringAsFixed(2)}'),
            ]),
            // My balance
            if (s.myBalance != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: balanceColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    s.myBalance! > 0.005
                        ? '${s.myName ?? "You"}: gets back ${s.trip.currency} ${s.myBalance!.toStringAsFixed(2)}'
                        : s.myBalance! < -0.005
                            ? '${s.myName ?? "You"}: owes ${s.trip.currency} ${s.myBalance!.abs().toStringAsFixed(2)}'
                            : '${s.myName ?? "You"}: settled up',
                    style: TextStyle(color: balanceColor, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
    ]);
  }
}

// ── Action Card (for empty state) ─────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onTap, child: Text(buttonLabel)),
            ),
          ],
        ),
      ),
    );
  }
}
