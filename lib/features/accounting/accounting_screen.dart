import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/money.dart';
import '../../data/collections/finance_collections.dart';
import '../../data/enums/app_enums.dart';
import '../shared/widgets.dart';

const expenseLabels = <ExpenseCategory, String>{
  ExpenseCategory.personnel: 'Personel',
  ExpenseCategory.rent: 'Kira',
  ExpenseCategory.electricity: 'Elektrik',
  ExpenseCategory.water: 'Su',
  ExpenseCategory.gas: 'Dogalgaz',
  ExpenseCategory.internet: 'Internet',
  ExpenseCategory.tax: 'Vergi',
  ExpenseCategory.supplies: 'Sarf/Malzeme',
  ExpenseCategory.maintenance: 'Bakim',
  ExpenseCategory.other: 'Diger',
};

const incomeLabels = <IncomeCategory, String>{
  IncomeCategory.sales: 'Satis',
  IncomeCategory.manual: 'Elle gelir',
  IncomeCategory.other: 'Diger',
};

enum _Period { day, week, month, year }

const _periodLabels = {
  _Period.day: 'Bugun',
  _Period.week: 'Hafta',
  _Period.month: 'Ay',
  _Period.year: 'Yil',
};

DateRange _rangeOf(_Period p) => switch (p) {
      _Period.day => DateRange.today(),
      _Period.week => DateRange.thisWeek(),
      _Period.month => DateRange.thisMonth(),
      _Period.year => DateRange.thisYear(),
    };

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(accountingEntriesProvider);
    final range = _rangeOf(_period);

    return Scaffold(
      appBar: AppBar(title: const Text('Muhasebe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kayit Ekle'),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Hata: $e'),
        data: (all) {
          final list = all
              .where((e) =>
                  !e.date.isBefore(range.start) && !e.date.isAfter(range.end))
              .toList();
          var income = 0, expense = 0;
          for (final e in list) {
            if (e.kind == AccountingKind.income) {
              income += e.amountKurus;
            } else {
              expense += e.amountKurus;
            }
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SegmentedButton<_Period>(
                  segments: [
                    for (final p in _Period.values)
                      ButtonSegment(value: p, label: Text(_periodLabels[p]!)),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) =>
                      setState(() => _period = s.first),
                ),
              ),
              _Totals(income: income, expense: expense),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_rounded,
                        message: 'Bu donemde kayit yok.')
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) =>
                            _EntryTile(list[i], onDelete: () => _delete(list[i])),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(AccountingEntry e) async {
    if (e.refOrderId != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Satistan gelen otomatik gelir silinemez.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kayit silinsin mi?'),
        content: Text(e.title.isEmpty ? 'Bu kayit' : e.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(accountingRepositoryProvider).softDelete(e.id);
    }
  }

  Future<void> _addEntry() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _EntryEditor(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kayit eklendi.')));
    }
  }
}

class _Totals extends StatelessWidget {
  final int income;
  final int expense;
  const _Totals({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          _card('Gelir', income, AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          _card('Gider', expense, AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          _card('Net', net, net >= 0 ? AppColors.amber : AppColors.danger),
        ],
      ),
    );
  }

  Widget _card(String label, int kurus, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              MoneyText(kurus,
                  color: color,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final AccountingEntry e;
  final VoidCallback onDelete;
  const _EntryTile(this.e, {required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = e.kind == AccountingKind.income;
    final cat = isIncome
        ? (incomeLabels[e.incomeCategory] ?? 'Gelir')
        : (expenseLabels[e.expenseCategory] ?? 'Gider');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            (isIncome ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
        child: Icon(
          isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: isIncome ? AppColors.success : AppColors.danger,
          size: 20,
        ),
      ),
      title: Text(e.title.isEmpty ? cat : e.title),
      subtitle: Text('$cat • ${DateX.dmy.format(e.date)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            isIncome ? e.amountKurus : -e.amountKurus,
            color: isIncome ? AppColors.success : AppColors.danger,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (e.refOrderId == null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

// ---------------- Kayit ekleme ----------------

class _EntryEditor extends ConsumerStatefulWidget {
  const _EntryEditor();

  @override
  ConsumerState<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<_EntryEditor> {
  AccountingKind _kind = AccountingKind.expense;
  ExpenseCategory _expenseCat = ExpenseCategory.supplies;
  IncomeCategory _incomeCat = IncomeCategory.manual;
  DateTime _date = DateTime.now();
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.parse(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gecerli bir tutar girin.')));
      return;
    }
    final entry = AccountingEntry()
      ..kind = _kind
      ..amountKurus = amount
      ..title = _titleCtrl.text.trim()
      ..date = _date
      ..expenseCategory = _kind == AccountingKind.expense ? _expenseCat : null
      ..incomeCategory = _kind == AccountingKind.income ? _incomeCat : null;
    await ref.read(accountingRepositoryProvider).addEntry(entry);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Kayit',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<AccountingKind>(
            segments: const [
              ButtonSegment(
                  value: AccountingKind.expense, label: Text('Gider')),
              ButtonSegment(
                  value: AccountingKind.income, label: Text('Gelir')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_kind == AccountingKind.expense)
            DropdownButtonFormField<ExpenseCategory>(
              value: _expenseCat,
              decoration: const InputDecoration(labelText: 'Gider kategorisi'),
              items: [
                for (final c in ExpenseCategory.values)
                  DropdownMenuItem(value: c, child: Text(expenseLabels[c]!)),
              ],
              onChanged: (v) => setState(() => _expenseCat = v!),
            )
          else
            DropdownButtonFormField<IncomeCategory>(
              value: _incomeCat,
              decoration: const InputDecoration(labelText: 'Gelir kategorisi'),
              items: [
                for (final c in IncomeCategory.values)
                  if (c != IncomeCategory.sales)
                    DropdownMenuItem(value: c, child: Text(incomeLabels[c]!)),
              ],
              onChanged: (v) => setState(() => _incomeCat = v!),
            ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Tutar (TL)', prefixIcon: Icon(Icons.payments_rounded)),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleCtrl,
            decoration:
                const InputDecoration(labelText: 'Aciklama (istege bagli)'),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_rounded),
            title: Text('Tarih: ${DateX.dmy.format(_date)}'),
            trailing: const Icon(Icons.edit_rounded),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
