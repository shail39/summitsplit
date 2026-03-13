import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/models.dart';

enum SplitMode { equal, exact, shares, percentage }

class AddExpenseScreen extends StatefulWidget {
  final String tripId;
  final List<Member> members;
  final String currency;
  final String? defaultPaidById;
  final Expense? editExpense; // non-null = edit mode

  const AddExpenseScreen({
    super.key,
    required this.tripId,
    required this.members,
    required this.currency,
    this.defaultPaidById,
    this.editExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _paidById;
  String _category = 'other';
  DateTime _date = DateTime.now();
  SplitMode _splitMode = SplitMode.equal;

  late Map<String, bool> _included;
  late Map<String, TextEditingController> _exactCtrls;
  late Map<String, TextEditingController> _shareCtrls;
  late Map<String, TextEditingController> _pctCtrls;

  bool get _isEditing => widget.editExpense != null;

  static const _categories = ['food', 'transport', 'accommodation', 'gear', 'other'];

  @override
  void initState() {
    super.initState();
    _included = {for (var m in widget.members) m.id: true};
    _exactCtrls = {for (var m in widget.members) m.id: TextEditingController()};
    _shareCtrls = {for (var m in widget.members) m.id: TextEditingController(text: '1')};
    _pctCtrls = {for (var m in widget.members) m.id: TextEditingController()};

    if (_isEditing) {
      final e = widget.editExpense!;
      _descCtrl.text = e.description;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _paidById = e.paidById;
      _category = e.category;
      _date = e.date;
      // Edit mode defaults to equal split (original split details aren't stored in Expense model)
    } else {
      _paidById = widget.defaultPaidById ?? (widget.members.isNotEmpty ? widget.members.first.id : null);
    }

    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    for (final c in _exactCtrls.values) c.dispose();
    for (final c in _shareCtrls.values) c.dispose();
    for (final c in _pctCtrls.values) c.dispose();
    super.dispose();
  }

  double get _total => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  List<Member> get _active => widget.members.where((m) => _included[m.id] == true).toList();

  Map<String, double> _computeSplits() {
    final total = _total;
    final active = _active;
    if (active.isEmpty || total <= 0) return {};

    switch (_splitMode) {
      case SplitMode.equal:
        final each = total / active.length;
        return {for (var m in active) m.id: each};

      case SplitMode.exact:
        return {for (var m in active) m.id: double.tryParse(_exactCtrls[m.id]!.text.trim()) ?? 0};

      case SplitMode.shares:
        final totalShares = active.fold<double>(0, (s, m) => s + (double.tryParse(_shareCtrls[m.id]!.text) ?? 0));
        if (totalShares <= 0) return {for (var m in active) m.id: 0};
        return {for (var m in active) m.id: total * (double.tryParse(_shareCtrls[m.id]!.text) ?? 0) / totalShares};

      case SplitMode.percentage:
        return {for (var m in active) m.id: total * (double.tryParse(_pctCtrls[m.id]!.text) ?? 0) / 100.0};
    }
  }

  double get _splitTotal => _computeSplits().values.fold(0.0, (a, b) => a + b);
  double get _remaining => _total - _splitTotal;
  bool get _splitValid => _remaining.abs() < 0.02 && _total > 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidById == null) return;
    if (_active.isEmpty) {
      _snack('Select at least one person to split with.');
      return;
    }
    if (!_splitValid) {
      _snack('Split doesn\'t add up. ${widget.currency} ${_remaining.abs().toStringAsFixed(2)} ${_remaining > 0 ? "unassigned" : "over"}');
      return;
    }

    final splits = _computeSplits().entries.where((e) => e.value > 0).map((e) => {'member_id': e.key, 'amount': e.value}).toList();

    try {
      if (_isEditing) {
        await ApiClient.updateExpense(widget.tripId, widget.editExpense!.id, _paidById!, _descCtrl.text.trim(), _category, _total, _date, splits);
      } else {
        await ApiClient.addExpense(widget.tripId, _paidById!, _descCtrl.text.trim(), _category, _total, _date, splits);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final splits = _computeSplits();
    final active = _active;
    final total = _total;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(labelText: 'Amount *', prefixText: '${widget.currency} ', border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paidById,
              decoration: const InputDecoration(labelText: 'Paid by', border: OutlineInputBorder()),
              items: widget.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
              onChanged: (v) => setState(() => _paidById = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1)))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                child: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Split mode
            const Text('Split mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            SegmentedButton<SplitMode>(
              selected: {_splitMode},
              onSelectionChanged: (s) => setState(() => _splitMode = s.first),
              segments: const [
                ButtonSegment(value: SplitMode.equal, label: Text('Equal')),
                ButtonSegment(value: SplitMode.exact, label: Text('Exact')),
                ButtonSegment(value: SplitMode.shares, label: Text('Shares')),
                ButtonSegment(value: SplitMode.percentage, label: Text('%')),
              ],
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 16),

            // Per-member rows
            ...widget.members.map((m) {
              final on = _included[m.id] == true;
              final amt = splits[m.id] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 36, child: Checkbox(value: on, onChanged: (v) => setState(() => _included[m.id] = v ?? false), visualDensity: VisualDensity.compact)),
                  Expanded(flex: 3, child: Text(m.name, style: TextStyle(color: on ? null : Colors.grey, fontWeight: FontWeight.w500))),
                  if (on) ...[
                    if (_splitMode == SplitMode.exact)
                      Expanded(flex: 3, child: TextField(
                        controller: _exactCtrls[m.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: const OutlineInputBorder(), prefixText: '${widget.currency} ', prefixStyle: const TextStyle(fontSize: 12)),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      )),
                    if (_splitMode == SplitMode.shares)
                      Expanded(flex: 2, child: TextField(
                        controller: _shareCtrls[m.id],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(), suffixText: 'x'),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      )),
                    if (_splitMode == SplitMode.percentage)
                      Expanded(flex: 2, child: TextField(
                        controller: _pctCtrls[m.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(), suffixText: '%'),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      )),
                    const SizedBox(width: 8),
                    SizedBox(width: 80, child: Text('${widget.currency} ${amt.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700]), textAlign: TextAlign.right)),
                  ] else
                    const Spacer(),
                ]),
              );
            }),

            // Status bar
            if (total > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _splitValid ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    _splitMode == SplitMode.equal && active.isNotEmpty
                        ? '${widget.currency} ${(total / active.length).toStringAsFixed(2)} each x ${active.length}'
                        : _splitValid
                            ? 'Split is balanced'
                            : _remaining > 0
                                ? '${widget.currency} ${_remaining.toStringAsFixed(2)} unassigned'
                                : 'Exceeds by ${widget.currency} ${(-_remaining).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _splitValid ? Colors.green.shade700 : Colors.orange.shade800,
                      fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  if (_splitMode != SplitMode.equal)
                    Text('${_splitTotal.toStringAsFixed(2)} / ${total.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ]),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_isEditing ? 'Update Expense' : 'Save Expense', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
