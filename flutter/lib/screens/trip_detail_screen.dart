import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_client.dart';
import '../models/models.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_trip!.name),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Settle Up'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Copy invite link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite link copied!')));
            },
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
            memberName: _memberName,
            onAddMember: () => _showAddMemberDialog(),
            onAddExpense: () => _goAddExpense(),
          ),
          _BalancesTab(balances: _balances, currency: _trip!.currency),
          _SettleTab(
            settlements: _settlements,
            currency: _trip!.currency,
            onMarkPaid: _markPaid,
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
              await ApiClient.addMember(widget.tripId, nameCtrl.text.trim(), emailCtrl.text.trim());
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
      builder: (_) => AddExpenseScreen(tripId: widget.tripId, members: _members, currency: _trip!.currency),
    ));
    _load();
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

// ── Expenses Tab ─────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final Trip trip;
  final List<Expense> expenses;
  final List<Member> members;
  final String Function(String) memberName;
  final VoidCallback onAddMember;
  final VoidCallback onAddExpense;

  const _ExpensesTab({
    required this.trip,
    required this.expenses,
    required this.members,
    required this.memberName,
    required this.onAddMember,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ListView(padding: const EdgeInsets.all(16), children: [
        // Members row
        Row(children: [
          const Text('Members', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          TextButton.icon(
            onPressed: onAddMember,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Add'),
          ),
        ]),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Text('No members yet.', style: TextStyle(color: Colors.grey[500]))
        else
          Wrap(
            spacing: 8,
            children: members.map((m) => Chip(label: Text(m.name))).toList(),
          ),
        const Divider(height: 28),
        // Expenses list
        if (expenses.isEmpty)
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
        else
          ...expenses.map((e) => _ExpenseTile(
                expense: e,
                currency: trip.currency,
                paidByName: memberName(e.paidById),
              )),
        const SizedBox(height: 80),
      ]),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          onPressed: members.isEmpty ? null : onAddExpense,
          backgroundColor: members.isEmpty ? Colors.grey : Theme.of(context).colorScheme.primary,
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

  const _ExpenseTile({required this.expense, required this.currency, required this.paidByName});

  static const _categoryIcons = {
    'food': Icons.restaurant,
    'transport': Icons.directions_car,
    'accommodation': Icons.hotel,
    'gear': Icons.backpack,
    'other': Icons.receipt,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcons[expense.category] ?? Icons.receipt;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('Paid by $paidByName · ${_fmtDate(expense.date)}',
            style: const TextStyle(fontSize: 12)),
        trailing: Text(
          '$currency ${expense.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
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

  const _BalancesTab({required this.balances, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return Center(child: Text('Add expenses to see balances.', style: TextStyle(color: Colors.grey[500])));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: balances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = balances[i];
        final isPositive = b.netBalance > 0.005;
        final isNegative = b.netBalance < -0.005;
        final color = isPositive
            ? const Color(0xFF2d6a4f)
            : isNegative
                ? Colors.red[600]!
                : Colors.grey[600]!;
        final label = isPositive
            ? 'gets back'
            : isNegative
                ? 'owes'
                : 'settled';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.12),
                child: Text(b.member.name[0].toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('$label  $currency ${b.netBalance.abs().toStringAsFixed(2)}',
                      style: TextStyle(color: color, fontSize: 13)),
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
                  backgroundColor: const Color(0xFFf97316),
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
