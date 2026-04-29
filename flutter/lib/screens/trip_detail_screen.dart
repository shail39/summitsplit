import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../services/user_profile.dart';
import 'add_expense_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  Trip? _trip;
  List<Member> _members = [];
  List<Expense> _expenses = [];
  List<Balance> _balances = [];
  List<Settlement> _settlements = [];
  bool _loading = true;

  String? _myMemberId;

  String get _prefsKey => 'identity_${widget.tripId}';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadIdentityAndData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadIdentityAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _myMemberId = prefs.getString(_prefsKey);
    await _load();
    if (_trip != null) {
      _saveVisitedTrip(prefs);
    }
    // Auto-detect by email if no identity saved
    if (_myMemberId == null && _members.isNotEmpty) {
      final profile = await UserProfile.load();
      if (profile != null) {
        final match = _members.cast<Member?>().firstWhere(
          (m) => m!.email.toLowerCase() == profile.email.toLowerCase(),
          orElse: () => null,
        );
        if (match != null) {
          await _saveIdentity(match.id);
          return; // identity set, no need to show picker
        }
      }
    }
    if (_myMemberId == null && mounted) {
      _showIdentityPicker();
    }
  }

  Future<void> _saveIdentity(String memberId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, memberId);
    setState(() => _myMemberId = memberId);
  }

  void _saveVisitedTrip(SharedPreferences prefs) {
    final trips = prefs.getStringList('visited_trips') ?? [];
    if (!trips.contains(widget.tripId)) {
      trips.insert(0, widget.tripId);
      prefs.setStringList('visited_trips', trips);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.getTrip(widget.tripId),
        ApiClient.getMembers(widget.tripId),
        ApiClient.getExpenses(widget.tripId),
        ApiClient.getBalances(widget.tripId),
        ApiClient.getSettlements(widget.tripId),
      ]);
      setState(() {
        _trip = results[0] as Trip;
        _members = results[1] as List<Member>;
        _expenses = results[2] as List<Expense>;
        _balances = results[3] as List<Balance>;
        _settlements = results[4] as List<Settlement>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _memberName(String id) =>
      _members.firstWhere((m) => m.id == id, orElse: () => Member(id: id, tripId: '', name: id, email: '')).name;

  Member? get _me => _myMemberId == null
      ? null
      : _members.cast<Member?>().firstWhere((m) => m?.id == _myMemberId, orElse: () => null);

  void _showIdentityPicker() async {
    final profile = await UserProfile.load();
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final emailCtrl = TextEditingController(text: profile?.email ?? '');
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Who are you?'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_members.isNotEmpty) ...[
                    Text('Select your name:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 8),
                    ..._members.map((m) => Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF6366f1).withValues(alpha: 0.12),
                          child: Text(m.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366f1), fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: m.email.isNotEmpty ? Text(m.email, style: TextStyle(fontSize: 11, color: Colors.grey[500])) : null,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () {
                          Navigator.pop(ctx);
                          _saveIdentity(m.id);
                        },
                      ),
                    )),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    _members.isEmpty ? 'Join this trip:' : 'Join as a new member:',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Your name *',
                      hintText: 'e.g. Alex',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    autofocus: _members.isEmpty,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      hintText: 'alex@example.com',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim().toLowerCase();
                        if (name.isEmpty || email.isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          final member = await ApiClient.addMember(widget.tripId, name, email);
                          await _saveIdentity(member.id);
                          // Also save/update local profile
                          await UserProfile.save(name, email);
                          _load();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Join Trip'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip'),
            ),
          ],
        ),
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

  void _showEditTripDialog() {
    final nameCtrl = TextEditingController(text: _trip!.name);
    final descCtrl = TextEditingController(text: _trip!.description);
    String currency = _trip!.currency;
    String selectedEmoji = _trip!.emoji.isNotEmpty ? _trip!.emoji : _tripEmojis[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Trip'),
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
                  SizedBox(
                    height: 90,
                    child: GridView.count(
                      crossAxisCount: 6,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: _tripEmojis.map((e) => GestureDetector(
                        onTap: () => setDialogState(() => selectedEmoji = e),
                        child: Container(
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
                  final trip = await ApiClient.updateTrip(
                    widget.tripId, nameCtrl.text.trim(), descCtrl.text.trim(), currency, selectedEmoji);
                  setState(() => _trip = trip);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final inviteUrl = 'https://app.summitsplit.com/trips/${widget.tripId}';
    final me = _me;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text('${_trip!.emoji.isNotEmpty ? '${_trip!.emoji} ' : ''}${_trip!.name}'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Settle Up'),
            Tab(text: 'Insights'),
          ],
        ),
        actions: [
          if (me != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: _showIdentityPicker,
                child: Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(me.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366f1), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  label: Text(me.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: Colors.white24,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'copy_link':
                  Clipboard.setData(ClipboardData(text: inviteUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied!')));
                  break;
                case 'edit_trip':
                  _showEditTripDialog();
                  break;
                case 'export_csv':
                  launchUrl(Uri.parse(ApiClient.exportCsvUrl(widget.tripId)), mode: LaunchMode.externalApplication);
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy_link', child: Row(children: [Icon(Icons.link, size: 18), SizedBox(width: 8), Text('Copy invite link')])),
              PopupMenuItem(value: 'edit_trip', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit trip')])),
              PopupMenuItem(value: 'export_csv', child: Row(children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Export CSV')])),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ExpensesTab(
            trip: _trip!,
            expenses: _expenses,
            members: _members,
            myMemberId: _myMemberId,
            balances: _balances,
            memberName: _memberName,
            onAddMember: () => _showAddMemberDialog(),
            onAddExpense: () => _goAddExpense(),
            onDeleteMember: _deleteMember,
            onEditExpense: _editExpense,
            onDeleteExpense: _deleteExpense,
          ),
          _BalancesTab(balances: _balances, currency: _trip!.currency, myMemberId: _myMemberId),
          _SettleTab(
            settlements: _settlements,
            currency: _trip!.currency,
            onMarkPaid: _markPaid,
          ),
          _InsightsTab(
            trip: _trip!,
            expenses: _expenses,
            members: _members,
            balances: _balances,
            memberName: _memberName,
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *'), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)'), keyboardType: TextInputType.emailAddress),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final member = await ApiClient.addMember(widget.tripId, nameCtrl.text.trim(), emailCtrl.text.trim());
              if (_myMemberId == null) {
                await _saveIdentity(member.id);
              }
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _goAddExpense() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddExpenseScreen(
        tripId: widget.tripId,
        members: _members,
        currency: _trip!.currency,
        defaultPaidById: _myMemberId,
      ),
    ));
    _load();
  }

  Future<void> _deleteMember(Member m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${m.name} from this trip?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.deleteMember(widget.tripId, m.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editExpense(Expense e) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddExpenseScreen(
        tripId: widget.tripId,
        members: _members,
        currency: _trip!.currency,
        defaultPaidById: _myMemberId,
        editExpense: e,
      ),
    ));
    _load();
  }

  Future<void> _deleteExpense(Expense e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${e.description}" (${_trip!.currency} ${e.amount.toStringAsFixed(2)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.deleteExpense(widget.tripId, e.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markPaid(Settlement s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Text(
          '${s.from.name} paid ${s.to.name} ${_trip!.currency} ${s.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiClient.recordPayment(widget.tripId, s.from.id, s.to.id, s.amount);
      _load();
    }
  }
}

// ── Expenses Tab with search/filter ─────────────────────────────────────

class _ExpensesTab extends StatefulWidget {
  final Trip trip;
  final List<Expense> expenses;
  final List<Member> members;
  final String? myMemberId;
  final List<Balance> balances;
  final String Function(String) memberName;
  final VoidCallback onAddMember;
  final VoidCallback onAddExpense;
  final void Function(Member) onDeleteMember;
  final void Function(Expense) onEditExpense;
  final void Function(Expense) onDeleteExpense;

  const _ExpensesTab({
    required this.trip,
    required this.expenses,
    required this.members,
    required this.myMemberId,
    required this.balances,
    required this.memberName,
    required this.onAddMember,
    required this.onAddExpense,
    required this.onDeleteMember,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  String _search = '';
  String? _filterCategory;
  String? _filterMember;
  bool _showFilters = false;

  List<Expense> get _filtered {
    var list = widget.expenses;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
        e.description.toLowerCase().contains(q) ||
        e.notes.toLowerCase().contains(q) ||
        widget.memberName(e.paidById).toLowerCase().contains(q)
      ).toList();
    }
    if (_filterCategory != null) {
      list = list.where((e) => e.category == _filterCategory).toList();
    }
    if (_filterMember != null) {
      list = list.where((e) => e.paidById == _filterMember).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalFiltered = filtered.fold<double>(0, (s, e) => s + e.amount);

    // Running totals per member
    final memberTotals = <String, double>{};
    for (final e in widget.expenses) {
      memberTotals[e.paidById] = (memberTotals[e.paidById] ?? 0) + e.amount;
    }

    return Stack(children: [
      ListView(padding: const EdgeInsets.all(16), children: [
        // Members section
        Row(children: [
          const Text('Members', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          TextButton.icon(
            onPressed: widget.onAddMember,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Add'),
          ),
        ]),
        const SizedBox(height: 8),
        if (widget.members.isEmpty)
          Text('No members yet. Add yourself first!', style: TextStyle(color: Colors.grey[500]))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.members.map((m) {
              final paid = memberTotals[m.id] ?? 0;
              return Chip(
                label: Text('${m.name}${paid > 0 ? ' (${widget.trip.currency} ${paid.toStringAsFixed(0)})' : ''}'),
                backgroundColor: m.id == widget.myMemberId ? const Color(0xFF6366f1).withValues(alpha: 0.15) : null,
                side: m.id == widget.myMemberId ? const BorderSide(color: Color(0xFF6366f1)) : null,
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => widget.onDeleteMember(m),
              );
            }).toList(),
          ),
        const Divider(height: 28),

        // Search bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Search expenses...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_search.isNotEmpty)
                  IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _search = '')),
                IconButton(
                  icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, size: 20,
                    color: (_filterCategory != null || _filterMember != null) ? const Color(0xFF6366f1) : null),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
              ],
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),

        // Filter chips
        if (_showFilters) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            // Category filter
            DropdownButton<String?>(
              value: _filterCategory,
              hint: const Text('Category', style: TextStyle(fontSize: 13)),
              underline: const SizedBox(),
              isDense: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('All categories')),
                ..._ExpenseTile._categoryEmojis.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.value} ${e.key[0].toUpperCase()}${e.key.substring(1)}', style: const TextStyle(fontSize: 13)),
                )),
              ],
              onChanged: (v) => setState(() => _filterCategory = v),
            ),
            const SizedBox(width: 8),
            // Member filter
            DropdownButton<String?>(
              value: _filterMember,
              hint: const Text('Paid by', style: TextStyle(fontSize: 13)),
              underline: const SizedBox(),
              isDense: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('All members')),
                ...widget.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name, style: const TextStyle(fontSize: 13)))),
              ],
              onChanged: (v) => setState(() => _filterMember = v),
            ),
            if (_filterCategory != null || _filterMember != null)
              TextButton(
                onPressed: () => setState(() { _filterCategory = null; _filterMember = null; }),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
          ]),
        ],

        const SizedBox(height: 8),

        // Summary bar
        if (widget.expenses.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366f1).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} expense${filtered.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                Text(
                  'Total: ${widget.trip.currency} ${totalFiltered.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        if (filtered.isEmpty && widget.expenses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No expenses yet.', style: TextStyle(color: Colors.grey[500])),
              ]),
            ),
          )
        else if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('No matching expenses.', style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else
          ...filtered.map((e) => _ExpenseTile(
                expense: e,
                currency: widget.trip.currency,
                paidByName: widget.memberName(e.paidById),
                isMe: e.paidById == widget.myMemberId,
                onEdit: () => widget.onEditExpense(e),
                onDelete: () => widget.onDeleteExpense(e),
              )),
        const SizedBox(height: 80),
      ]),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          onPressed: widget.members.isEmpty ? null : widget.onAddExpense,
          backgroundColor: widget.members.isEmpty ? Colors.grey : Theme.of(context).colorScheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
        ),
      ),
    ]);
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final String currency;
  final String paidByName;
  final bool isMe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseTile({required this.expense, required this.currency, required this.paidByName, this.isMe = false, required this.onEdit, required this.onDelete});

  static const _categoryEmojis = {
    'food': '\u{1F354}',
    'drinks': '\u{1F37B}',
    'transport': '\u{1F697}',
    'accommodation': '\u{1F3E8}',
    'gear': '\u{1F392}',
    'activities': '\u{1F3BF}',
    'entertainment': '\u{1F3AC}',
    'shopping': '\u{1F6CD}',
    'groceries': '\u{1F6D2}',
    'health': '\u{1FA7A}',
    'tips': '\u{1F4B0}',
    'fees': '\u{1F4B3}',
    'other': '\u{1F4CB}',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _categoryEmojis[expense.category] ?? '\u{1F4CB}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isMe ? const Color(0xFF6366f1).withValues(alpha: 0.3) : Colors.grey.shade100),
      ),
      color: isMe ? const Color(0xFF6366f1).withValues(alpha: 0.04) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paid by ${isMe ? "you" : paidByName} \u{00B7} ${_fmtDate(expense.date)}',
                style: const TextStyle(fontSize: 12)),
            if (expense.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(expense.notes, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currency ${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 20,
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
}

// ── Balances Tab ──────────────────────────────────────────────────────────────

class _BalancesTab extends StatelessWidget {
  final List<Balance> balances;
  final String currency;
  final String? myMemberId;

  const _BalancesTab({required this.balances, required this.currency, this.myMemberId});

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return Center(child: Text('Add expenses to see balances.', style: TextStyle(color: Colors.grey[500])));
    }
    final sorted = List<Balance>.from(balances);
    if (myMemberId != null) {
      sorted.sort((a, b) {
        if (a.member.id == myMemberId) return -1;
        if (b.member.id == myMemberId) return 1;
        return 0;
      });
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = sorted[i];
        final isMe = b.member.id == myMemberId;
        final isPositive = b.netBalance > 0.005;
        final isNegative = b.netBalance < -0.005;
        final color = isPositive
            ? const Color(0xFF6366f1)
            : isNegative
                ? Colors.red[600]!
                : Colors.grey[600]!;
        final label = isPositive ? 'gets back' : isNegative ? 'owes' : 'settled';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isMe ? color : color.withValues(alpha: 0.3), width: isMe ? 2 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(b.member.name[0].toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isMe ? '${b.member.name} (you)' : b.member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('$label  $currency ${b.netBalance.abs().toStringAsFixed(2)}',
                      style: TextStyle(color: color, fontSize: 13)),
                  Text('Paid $currency ${b.totalPaid.toStringAsFixed(2)} \u{00B7} Owes $currency ${b.totalOwed.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
              ),
              Text(
                '${b.netBalance >= 0 ? '+' : ''}${b.netBalance.toStringAsFixed(2)}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Settle Up Tab ─────────────────────────────────────────────────────────────

class _SettleTab extends StatelessWidget {
  final List<Settlement> settlements;
  final String currency;
  final Future<void> Function(Settlement) onMarkPaid;

  const _SettleTab({
    required this.settlements,
    required this.currency,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    if (settlements.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green[400]),
          const SizedBox(height: 12),
          const Text('All settled up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Everyone is even.', style: TextStyle(color: Colors.grey[500])),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: settlements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = settlements[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.orange.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _Avatar(s.from.name, Colors.red.shade50, Colors.red.shade700),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                    ),
                    _Avatar(s.to.name, Colors.green.shade50, Colors.green.shade700),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '${s.from.name} pays ${s.to.name}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text('$currency ${s.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
              ),
              ElevatedButton(
                onPressed: () => onMarkPaid(s),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf59e0b),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Mark Paid', style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color bg;
  final Color fg;
  const _Avatar(this.name, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 16,
        backgroundColor: bg,
        child: Text(name[0].toUpperCase(), style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13)),
      );
}

// ── Insights Tab ─────────────────────────────────────────────────────────────

class _InsightsTab extends StatelessWidget {
  final Trip trip;
  final List<Expense> expenses;
  final List<Member> members;
  final List<Balance> balances;
  final String Function(String) memberName;

  const _InsightsTab({
    required this.trip,
    required this.expenses,
    required this.members,
    required this.balances,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.insights_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Add expenses to see insights.', style: TextStyle(color: Colors.grey[500])),
        ]),
      );
    }

    final currency = trip.currency;
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final avgExpense = total / expenses.length;

    // Date range
    final dates = expenses.map((e) => e.date).toList()..sort();
    final firstDate = dates.first;
    final lastDate = dates.last;
    final tripDays = lastDate.difference(firstDate).inDays + 1;
    final dailyAvg = total / tripDays;

    // Category breakdown
    final categoryTotals = <String, double>{};
    for (final e in expenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Member spending
    final memberSpending = <String, double>{};
    for (final e in expenses) {
      memberSpending[e.paidById] = (memberSpending[e.paidById] ?? 0) + e.amount;
    }
    final sortedMembers = memberSpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Top expense
    final topExpense = expenses.reduce((a, b) => a.amount > b.amount ? a : b);

    // Per-person cost
    final perPerson = members.isNotEmpty ? total / members.length : total;

    // Category emojis
    const catEmojis = {
      'food': '\u{1F354}', 'drinks': '\u{1F37B}', 'transport': '\u{1F697}',
      'accommodation': '\u{1F3E8}', 'gear': '\u{1F392}', 'activities': '\u{1F3BF}',
      'entertainment': '\u{1F3AC}', 'shopping': '\u{1F6CD}', 'groceries': '\u{1F6D2}',
      'health': '\u{1FA7A}', 'tips': '\u{1F4B0}', 'fees': '\u{1F4B3}', 'other': '\u{1F4CB}',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview cards
        _InsightSection(title: 'Overview', children: [
          Row(children: [
            Expanded(child: _StatCard(label: 'Total Spent', value: '$currency ${total.toStringAsFixed(2)}', icon: Icons.payments_outlined, color: const Color(0xFF6366f1))),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Expenses', value: '${expenses.length}', icon: Icons.receipt_long_outlined, color: Colors.orange)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(label: 'Per Person', value: '$currency ${perPerson.toStringAsFixed(2)}', icon: Icons.person_outline, color: Colors.teal)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Avg Expense', value: '$currency ${avgExpense.toStringAsFixed(2)}', icon: Icons.trending_up, color: Colors.blue)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(label: 'Trip Days', value: '$tripDays', icon: Icons.calendar_today_outlined, color: Colors.purple)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Daily Avg', value: '$currency ${dailyAvg.toStringAsFixed(2)}', icon: Icons.today_outlined, color: Colors.green)),
          ]),
        ]),

        const SizedBox(height: 20),

        // Biggest expense
        _InsightSection(title: 'Biggest Expense', children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.amber.shade200)),
            color: Colors.amber.shade50,
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.star, color: Colors.white)),
              title: Text(topExpense.description, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Paid by ${memberName(topExpense.paidById)}'),
              trailing: Text('$currency ${topExpense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // Category breakdown
        _InsightSection(title: 'Spending by Category', children: [
          ...sortedCategories.map((entry) {
            final pct = (entry.value / total * 100);
            final emoji = catEmojis[entry.key] ?? '\u{1F4CB}';
            final name = entry.key[0].toUpperCase() + entry.key.substring(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('$emoji $name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('$currency ${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 6),
                    Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / total,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF6366f1),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ]),

        const SizedBox(height: 20),

        // Who paid the most
        _InsightSection(title: 'Who Paid the Most', children: [
          ...sortedMembers.map((entry) {
            final pct = (entry.value / total * 100);
            final name = memberName(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF6366f1).withValues(alpha: 0.12),
                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366f1), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('$currency ${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 6),
                    Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / total,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.orange,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ]),

        const SizedBox(height: 20),

        // Spending timeline (by day)
        _InsightSection(title: 'Spending Timeline', children: [
          ..._buildTimeline(expenses, currency, total),
        ]),

        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildTimeline(List<Expense> expenses, String currency, double total) {
    final byDay = <String, double>{};
    for (final e in expenses) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      byDay[key] = (byDay[key] ?? 0) + e.amount;
    }
    final sortedDays = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxDay = sortedDays.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return sortedDays.map((entry) {
      final d = DateTime.parse(entry.key);
      final label = '${months[d.month - 1]} ${d.day}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 52, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxDay > 0 ? entry.value / maxDay : 0,
                backgroundColor: Colors.grey.shade100,
                color: const Color(0xFF6366f1).withValues(alpha: 0.7),
                minHeight: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$currency ${entry.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
    }).toList();
  }
}

class _InsightSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InsightSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
