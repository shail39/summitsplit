import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trip> _myTrips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyTrips();
  }

  Future<void> _loadMyTrips() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('visited_trips') ?? [];
    final trips = <Trip>[];
    for (final id in ids) {
      try {
        trips.add(await ApiClient.getTrip(id));
      } catch (_) {
        // Trip may have been deleted — skip it
      }
    }
    if (mounted) {
      setState(() {
        _myTrips = trips;
        _loading = false;
      });
    }
  }

  Future<void> _removeTrip(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('visited_trips') ?? [];
    ids.remove(tripId);
    await prefs.setStringList('visited_trips', ids);
    setState(() => _myTrips.removeWhere((t) => t.id == tripId));
  }

  @override
  Widget build(BuildContext context) {
    final hasTrips = _myTrips.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('SummitSplit')),
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
                      ..._myTrips.map((trip) => _TripCard(
                            trip: trip,
                            onTap: () => context.go('/trips/${trip.id}'),
                            onRemove: () => _removeTrip(trip.id),
                          )),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => _showJoinDialog(context),
                        icon: const Icon(Icons.link),
                        label: const Text('Join a Trip'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF2d6a4f)),
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

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String currency = 'USD';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Trip'),
          content: Column(
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
                onChanged: (v) => setState(() => currency = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final trip = await ApiClient.createTrip(
                    nameCtrl.text.trim(), descCtrl.text.trim(), currency);
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

// ── Trip Card ──────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _TripCard({required this.trip, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF2d6a4f).withValues(alpha: 0.12),
              child: const Icon(Icons.terrain, color: Color(0xFF2d6a4f), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (trip.description.isNotEmpty)
                  Text(trip.description, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(trip.currency, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
        ),
      ),
    );
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
