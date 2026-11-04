import 'package:flutter/material.dart';

import '../models/recurring_transaction.dart';
import '../theme/app_colors.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({
    required this.initialRules,
    required this.onSave,
    super.key,
  });

  final List<RecurringTransaction> initialRules;
  final Future<List<RecurringTransaction>?> Function(List<RecurringTransaction>)
  onSave;

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  late List<RecurringTransaction> _rules;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rules = List.of(widget.initialRules);
  }

  Future<void> _openForm({RecurringTransaction? rule}) async {
    final result = await showModalBottomSheet<RecurringTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _RecurringFormSheet(rule: rule),
    );
    if (result == null || !mounted) return;

    final updated = List<RecurringTransaction>.of(_rules);
    final index = updated.indexWhere((item) => item.id == result.id);
    if (index < 0) {
      updated.insert(0, result);
    } else {
      updated[index] = result;
    }
    await _save(updated, 'Recurring transaction saved.');
  }

  Future<void> _togglePaused(RecurringTransaction rule) async {
    final updated = _rules
        .map(
          (item) => item.id == rule.id
              ? item.copyWith(isPaused: !item.isPaused)
              : item,
        )
        .toList();
    await _save(
      updated,
      rule.isPaused
          ? 'Recurring transaction resumed.'
          : 'Recurring transaction paused.',
    );
  }

  Future<void> _delete(RecurringTransaction rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recurring transaction?'),
        content: Text('Delete "${rule.title}" and its future schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(
      _rules.where((item) => item.id != rule.id).toList(),
      'Recurring transaction deleted.',
    );
  }

  Future<void> _save(
    List<RecurringTransaction> updated, [
    String message = 'Changes saved.',
  ]) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final savedRules = await widget.onSave(updated);
      if (!mounted) return;
      if (savedRules == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save schedule. Please retry.'),
          ),
        );
        return;
      }
      setState(() => _rules = List.of(savedRules));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error, stackTrace) {
      debugPrint('Failed to save recurring transaction: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save schedule. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Recurring Transactions',
        style: TextStyle(color: navy, fontWeight: FontWeight.bold),
      ),
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
    body: _rules.isEmpty
        ? _emptyState()
        : ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              const Text(
                'Schedules run when the app opens or resumes. Missed active '
                'dates are caught up once; paused dates are skipped.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 14),
              for (final rule in _rules) _ruleCard(rule),
            ],
          ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('add-recurring-transaction'),
      onPressed: _isSaving ? null : () => _openForm(),
      backgroundColor: green,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.repeat),
      label: const Text('Add schedule'),
    ),
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, color: green, size: 44),
          const SizedBox(height: 14),
          const Text(
            'No recurring transactions',
            style: TextStyle(
              color: navy,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Set up regular income or expenses to add them automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _ruleCard(RecurringTransaction rule) {
    final status = rule.isPaused
        ? 'Paused'
        : rule.isCompleted
        ? 'Completed'
        : 'Next: ${_formatDate(rule.nextRunDate)}';
    final amount = '₹${rule.amount.toStringAsFixed(2)}';
    return Card(
      key: Key('recurring-rule-${rule.id}'),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (rule.isIncome ? green : const Color(0xFFEF4444))
                  .withValues(alpha: 0.12),
              child: Icon(
                Icons.repeat,
                color: rule.isIncome ? green : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.title,
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rule.category} · ${rule.frequency.name} · '
                    '${rule.isIncome ? 'Income' : 'Expense'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$status · $amount'
                    '${rule.endDate == null ? '' : ' · Ends ${_formatDate(rule.endDate!)}'}',
                    style: TextStyle(
                      color: rule.isPaused ? Colors.orange.shade800 : green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: Key('recurring-menu-${rule.id}'),
              enabled: !_isSaving,
              onSelected: (action) {
                if (action == 'edit') _openForm(rule: rule);
                if (action == 'pause') _togglePaused(rule);
                if (action == 'delete') _delete(rule);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'pause',
                  child: Text(rule.isPaused ? 'Resume' : 'Pause'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _RecurringFormSheet extends StatefulWidget {
  const _RecurringFormSheet({required this.rule});

  final RecurringTransaction? rule;

  @override
  State<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<_RecurringFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _category;
  late bool _isIncome;
  late RecurrenceFrequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _hasEndDate = false;
  bool _isSaving = false;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _titleController = TextEditingController(text: rule?.title ?? '');
    _amountController = TextEditingController(
      text: rule?.amount.toString() ?? '',
    );
    _category = rule?.category ?? 'Food';
    _isIncome = rule?.isIncome ?? false;
    _frequency = rule?.frequency ?? RecurrenceFrequency.monthly;
    _startDate = rule?.startDate ?? DateTime.now();
    _endDate = rule?.endDate;
    _hasEndDate = rule?.endDate != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = selected;
      }
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.isEmpty || amount == null || !amount.isFinite || amount <= 0) {
      _showError('Enter a title and a valid positive amount.');
      return;
    }
    if (_hasEndDate && _endDate != null && _endDate!.isBefore(_startDate)) {
      _showError('The end date must be on or after the start date.');
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final previous = widget.rule;
    final startChanged =
        previous != null && !_sameDate(previous.startDate, _startDate);
    Navigator.pop(
      context,
      RecurringTransaction(
        id: previous?.id,
        title: title,
        category: _category,
        amount: amount,
        isIncome: _isIncome,
        frequency: _frequency,
        startDate: _startDate,
        endDate: _hasEndDate ? _endDate : null,
        nextRunDate: startChanged
            ? _startDate
            : previous?.nextRunDate ?? _startDate,
        isPaused: previous?.isPaused ?? false,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isIncome
        ? ['Salary', 'Business', 'Allowance', 'Other']
        : [
            'Food',
            'Travel',
            'Shopping',
            'Education',
            'Entertainment',
            'Health',
            'Other',
          ];
    if (!categories.contains(_category)) categories.add(_category);

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing
                  ? 'Edit recurring transaction'
                  : 'New recurring transaction',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Expense')),
                ButtonSegment(value: true, label: Text('Income')),
              ],
              selected: {_isIncome},
              onSelectionChanged: (value) => setState(() {
                _isIncome = value.first;
                _category = _isIncome ? 'Salary' : 'Food';
              }),
            ),
            const SizedBox(height: 14),
            const Text('Title'),
            const SizedBox(height: 6),
            TextField(
              key: const Key('recurring-title-field'),
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g. Monthly rent',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Amount'),
            const SizedBox(height: 6),
            TextField(
              key: const Key('recurring-amount-field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: const Key('recurring-category-field'),
              initialValue: _category,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 14),
            const Text('Frequency'),
            const SizedBox(height: 6),
            DropdownButtonFormField<RecurrenceFrequency>(
              key: const Key('recurring-frequency-field'),
              initialValue: _frequency,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: RecurrenceFrequency.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_frequencyLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('recurring-start-date'),
              onPressed: () => _pickDate(start: true),
              icon: const Icon(Icons.calendar_today),
              label: Text('Starts ${_formatDate(_startDate)}'),
            ),
            SwitchListTile(
              key: const Key('recurring-has-end-date'),
              contentPadding: EdgeInsets.zero,
              value: _hasEndDate,
              activeThumbColor: green,
              title: const Text('Set an end date'),
              onChanged: (value) => setState(() {
                _hasEndDate = value;
                _endDate ??= _startDate;
              }),
            ),
            if (_hasEndDate)
              OutlinedButton.icon(
                key: const Key('recurring-end-date'),
                onPressed: () => _pickDate(start: false),
                icon: const Icon(Icons.event_busy),
                label: Text('Ends ${_formatDate(_endDate ?? _startDate)}'),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const Key('save-recurring-transaction'),
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_isEditing ? 'Save changes' : 'Create schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _frequencyLabel(RecurrenceFrequency frequency) =>
      frequency.name[0].toUpperCase() + frequency.name.substring(1);

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
