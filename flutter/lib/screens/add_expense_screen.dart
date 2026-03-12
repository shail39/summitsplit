import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/models.dart';

class AddExpenseScreen extends StatefulWidget {
  final String tripId;
  final List<Member> members;
  final String currency;

  const AddExpenseScreen({
    super.key,
    required this.tripId,
    required this.members,
    required this.currency,
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

  // Which members are included in the split (all by default)
  late Map<String, bool> _splitIncluded;

  static const _categories = ['food', 'transport', 'accommodation', 'gear', 'other'];

  @override
  void initState() {
    super.initState();
    _paidById = widget.members.isNotEmpty ? widget.members.first.id : null;
    _splitIncluded = {for (var m in widget.members) m.id: true};
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<Member> get _includedMembers =>
      widget.members.where((m) => _splitIncluded[m.id] == true).toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidById == null) return;
    final included = _includedMembers;
    if (included.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one person to split with.')));
      return;
    }

    final amount = double.parse(_amountCtrl.text.trim());
    final splitAmount = amount / included.length;
    final splits = included.map((m) => {'member_id': m.id, 'amount': splitAmount}).toList();

    try {
      await ApiClient.addExpense(
        widget.tripId, _paidById!, _descCtrl.text.trim(),
        _category, amount, _date, splits,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final included = _includedMembers;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final perPerson = included.isNotEmpty ? amount / included.length : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: 'Amount *',
                prefixText: '${widget.currency} ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Paid by
            DropdownButtonFormField<String>(
              value: _paidById,
              decoration: const InputDecoration(labelText: 'Paid by', border: OutlineInputBorder()),
              items: widget.members
                  .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: (v) => setState(() => _paidById = v),
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                child: Text('${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}'),
              ),
            ),
            const SizedBox(height: 24),

            // Split among
            Row(children: [
              const Text('Split among', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              if (perPerson > 0)
                Text('${widget.currency} ${perPerson.toStringAsFixed(2)} each',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ...widget.members.map((m) => CheckboxListTile(
                  dense: true,
                  value: _splitIncluded[m.id] ?? false,
                  title: Text(m.name),
                  onChanged: (v) => setState(() => _splitIncluded[m.id] = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                )),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save Expense', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
