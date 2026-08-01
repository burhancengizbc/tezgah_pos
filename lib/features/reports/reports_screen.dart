import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/money.dart';
import '../../domain/models/report_models.dart';
import '../shared/widgets.dart';

const _expenseLabelByName = <String, String>{
  'personnel': 'Personel',
  'rent': 'Kira',
  'electricity': 'Elektrik',
  'water': 'Su',
  'gas': 'Dogalgaz',
  'internet': 'Internet',
  'tax': 'Vergi',
  'supplies': 'Sarf/Malzeme',
  'maintenance': 'Bakim',
  'other': 'Diger',
};

enum _Period { day, week, month, year, custom }

const _periodLabels = {
  _Period.day: 'Bugun',
  _Period.week: 'Hafta',
  _Period.month: 'Ay',
  _Period.year: 'Yil',
  _Period.custom: 'Ozel',
};

class _ReportData {
  final SalesSummary summary;
  final List<ProductSalesRow> top;
  final List<ProductSalesRow> bottom;
  final List<CategorySalesRow> categories;
  final List<ExpenseRow> expenses;
  const _ReportData(
      this.summary, this.top, this.bottom, this.categories, this.expenses);
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Period _period = _Period.day;
  DateTimeRange? _customRange;
  _ReportData? _data;
  bool _loading = true;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateRange get _range {
    switch (_period) {
      case _Period.day:
        return DateRange.today();
      case _Period.week:
        return DateRange.thisWeek();
      case _Period.month:
        return DateRange.thisMonth();
      case _Period.year:
        return DateRange.thisYear();
      case _Period.custom:
        final r = _customRange;
        if (r == null) return DateRange.today();
        return DateRange(
            DateX.startOfDay(r.start), DateX.endOfDay(r.end));
    }
  }

  String get _periodText {
    if (_period == _Period.custom && _customRange != null) {
      return '${DateX.dmy.format(_customRange!.start)} - ${DateX.dmy.format(_customRange!.end)}';
    }
    return _periodLabels[_period]!;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = ref.read(reportServiceProvider);
    final r = _range;
    final results = await Future.wait([
      svc.summary(r.start, r.end),
      svc.productSales(r.start, r.end, limit: 10),
      svc.productSales(r.start, r.end, limit: 5, ascending: true),
      svc.categorySales(r.start, r.end),
      svc.expensesByCategory(r.start, r.end),
    ]);
    if (!mounted) return;
    setState(() {
      _data = _ReportData(
        results[0] as SalesSummary,
        results[1] as List<ProductSalesRow>,
        results[2] as List<ProductSalesRow>,
        results[3] as List<CategorySalesRow>,
        results[4] as List<ExpenseRow>,
      );
      _loading = false;
    });
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customRange ??
          DateTimeRange(
              start: DateX.startOfMonth(now), end: now),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = _Period.custom;
      });
      _load();
    }
  }

  Future<void> _exportPdf({required bool share}) async {
    final data = _data;
    if (data == null) return;
    setState(() => _pdfBusy = true);
    try {
      final profile = await ref.read(settingsRepositoryProvider).getProfile();
      final bytes = await ref.read(reportPdfServiceProvider).build(
            businessName: profile.name,
            periodLabel: _periodText,
            generatedAt: DateTime.now(),
            summary: data.summary,
            topProducts: data.top,
            bottomProducts: data.bottom,
            categories: data.categories,
            expenses: data.expenses,
            expenseLabels: _expenseLabelByName,
          );
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: 'tezgah_rapor.pdf');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        actions: [
          if (_pdfBusy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              tooltip: 'Yazdir / Onizle',
              icon: const Icon(Icons.print_rounded),
              onPressed: _data == null ? null : () => _exportPdf(share: false),
            ),
            IconButton(
              tooltip: 'PDF Paylas',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _data == null ? null : () => _exportPdf(share: true),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_Period>(
                      segments: [
                        for (final p in _Period.values)
                          ButtonSegment(
                              value: p, label: Text(_periodLabels[p]!)),
                      ],
                      selected: {_period},
                      onSelectionChanged: (s) {
                        final p = s.first;
                        if (p == _Period.custom) {
                          _pickCustom();
                        } else {
                          setState(() => _period = p);
                          _load();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_period == _Period.custom && _customRange != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_periodText,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _data == null
                    ? const EmptyState(
                        icon: Icons.insights_rounded, message: 'Veri yok.')
                    : _ReportBody(data: _data!),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final _ReportData data;
  const _ReportBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final avg =
        s.orderCount == 0 ? 0 : (s.totalSalesKurus / s.orderCount).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      children: [
        // --- Ozet ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _line('Ciro (net)', s.totalSalesKurus, strong: true),
                _line('Urun maliyeti', s.totalCostKurus),
                _line('Brut kar', s.grossProfitKurus,
                    strong: true, color: AppColors.success),
                _line('Giderler', -s.expensesKurus, color: AppColors.danger),
                const Divider(),
                _line('Net kar', s.netProfitKurus,
                    strong: true,
                    color: s.netProfitKurus >= 0
                        ? AppColors.success
                        : AppColors.danger),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _miniCard(context, 'Siparis', '${s.orderCount}'),
            const SizedBox(width: AppSpacing.sm),
            _miniCardMoney(context, 'Ort. fis', avg),
            const SizedBox(width: AppSpacing.sm),
            _miniCardMoney(context, 'KDV', s.vatTotalKurus),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        _SectionHeader('En Cok Satan Urunler'),
        if (data.top.isEmpty)
          const _NoData()
        else
          for (final r in data.top) _ProductRow(r),

        const SizedBox(height: AppSpacing.lg),
        _SectionHeader('En Az Satan Urunler'),
        if (data.bottom.isEmpty)
          const _NoData()
        else
          for (final r in data.bottom) _ProductRow(r),

        const SizedBox(height: AppSpacing.lg),
        _SectionHeader('Kategori Kirilimi'),
        if (data.categories.isEmpty)
          const _NoData()
        else
          _CategoryBars(rows: data.categories),

        const SizedBox(height: AppSpacing.lg),
        _SectionHeader('Gider Kirilimi'),
        if (data.expenses.isEmpty)
          const _NoData()
        else
          for (final e in data.expenses)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.north_east_rounded,
                  color: AppColors.danger, size: 18),
              title: Text(_expenseLabelByName[e.category] ?? e.category),
              trailing: MoneyText(e.amountKurus,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
      ],
    );
  }

  Widget _line(String label, int kurus, {bool strong = false, Color? color}) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      fontSize: strong ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          MoneyText(kurus, style: style, color: color),
        ],
      ),
    );
  }

  Widget _miniCard(BuildContext c, String label, String value) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            child: Column(children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  Widget _miniCardMoney(BuildContext c, String label, int kurus) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            child: Column(children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              MoneyText(kurus,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _NoData extends StatelessWidget {
  const _NoData();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text('Bu donemde veri yok.',
            style: TextStyle(color: AppColors.dTextDim)),
      );
}

class _ProductRow extends StatelessWidget {
  final ProductSalesRow r;
  const _ProductRow(this.r);
  @override
  Widget build(BuildContext context) {
    final qtyStr =
        r.qty == r.qty.roundToDouble() ? r.qty.toInt().toString() : r.qty.toStringAsFixed(2);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(r.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$qtyStr adet • kar ${Money.format(r.profitKurus)}'),
      trailing: MoneyText(r.salesKurus,
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  final List<CategorySalesRow> rows;
  const _CategoryBars({required this.rows});

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(1, (m, r) => r.salesKurus > m ? r.salesKurus : m);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(r.categoryName,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    MoneyText(r.salesKurus,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                          height: 8,
                          color: AppColors.amber.withValues(alpha: 0.15)),
                      FractionallySizedBox(
                        widthFactor: (r.salesKurus / max).clamp(0.02, 1.0),
                        child: Container(height: 8, color: AppColors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
