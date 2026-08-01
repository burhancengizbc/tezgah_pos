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

const _cashMovementLabels = <CashMovementType, String>{
  CashMovementType.open: 'Acilis',
  CashMovementType.close: 'Kapanis',
  CashMovementType.sale: 'Satis',
  CashMovementType.refund: 'Iade',
  CashMovementType.cashIn: 'Para Girisi',
  CashMovementType.cashOut: 'Para Cikisi',
};

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(openCashSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasa'),
        actions: [
          IconButton(
            tooltip: 'Gecmis vardiyalar',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CashHistoryScreen()),
            ),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
            icon: Icons.error_outline, message: 'Hata: $e'),
        data: (session) => session == null
            ? _ClosedView(onOpen: (float) => _openCash(context, ref, float))
            : _OpenView(session: session),
      ),
    );
  }

  Future<void> _openCash(BuildContext context, WidgetRef ref, int float) async {
    await ref.read(cashRepositoryProvider).openCash(float);
  }
}

// ---------------- Kasa kapali ----------------

class _ClosedView extends StatefulWidget {
  final ValueChanged<int> onOpen;
  const _ClosedView({required this.onOpen});

  @override
  State<_ClosedView> createState() => _ClosedViewState();
}

class _ClosedViewState extends State<_ClosedView> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_rounded,
                  size: 56, color: AppColors.dTextDim),
              const SizedBox(height: AppSpacing.md),
              Text('Kasa Kapali',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Gune baslamak icin acilis bakiyesini girip kasayi acin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Acilis bakiyesi (TL)',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => widget.onOpen(Money.parse(_ctrl.text)),
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Kasayi Ac'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Kasa acik ----------------

class _OpenView extends ConsumerWidget {
  final CashSession session;
  const _OpenView({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moves = ref.watch(cashMovementsProvider(session.id));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SummaryCard(session: session),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _movementDialog(
                    context, ref, CashMovementType.cashIn),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Para Girisi'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _movementDialog(
                    context, ref, CashMovementType.cashOut),
                icon: const Icon(Icons.remove_rounded),
                label: const Text('Para Cikisi'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => _closeDialog(context, ref),
          icon: const Icon(Icons.nights_stay_rounded),
          label: const Text('Gun Sonu / Kasa Kapat'),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Hareketler', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        moves.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Hata: $e'),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('Henuz hareket yok.'),
                )
              : Column(
                  children: [for (final m in list) _MovementTile(m)],
                ),
        ),
      ],
    );
  }

  Future<void> _movementDialog(
      BuildContext context, WidgetRef ref, CashMovementType type) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final isIn = type == CashMovementType.cashIn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isIn ? 'Para Girisi' : 'Para Cikisi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tutar (TL)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                  labelText: 'Aciklama (orn. tedarikci odemesi)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok == true) {
      final amount = Money.parse(amountCtrl.text);
      if (amount > 0) {
        await ref.read(cashRepositoryProvider).addMovement(
              sessionId: session.id,
              type: type,
              amountKurus: amount,
              reason: reasonCtrl.text.trim(),
            );
      }
    }
  }

  Future<void> _closeDialog(BuildContext context, WidgetRef ref) async {
    final countedCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gun Sonu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Beklenen nakit: ${Money.format(session.expectedCashKurus)}'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: countedCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Sayilan nakit (TL)',
                helperText: 'Kasadaki gercek nakit',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kasayi Kapat')),
        ],
      ),
    );
    if (confirmed == true) {
      final counted = Money.parse(countedCtrl.text);
      final closed =
          await ref.read(cashRepositoryProvider).closeCash(session.id, counted);
      if (context.mounted) {
        await showZReport(context, closed);
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final CashSession session;
  const _SummaryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale_rounded, color: AppColors.amber),
                const SizedBox(width: AppSpacing.sm),
                Text('Acik Vardiya',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(DateX.dmyHm.format(session.openedAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            _row('Acilis bakiyesi', session.openingFloatKurus),
            _row('Nakit satis', session.cashSalesKurus),
            _row('Kart satis', session.cardSalesKurus),
            _row('Diger (yemek k. vb.)', session.otherSalesKurus),
            _row('Elle para girisi', session.cashInKurus),
            _row('Elle para cikisi', -session.cashOutKurus),
            const Divider(height: AppSpacing.xl),
            _row('Beklenen nakit', session.expectedCashKurus, strong: true),
            _row('Toplam satis', session.totalSalesKurus, strong: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int kurus, {bool strong = false}) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      fontSize: strong ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          MoneyText(kurus, style: style),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final CashMovement m;
  const _MovementTile(this.m);

  @override
  Widget build(BuildContext context) {
    final isOut = m.type == CashMovementType.cashOut ||
        m.type == CashMovementType.refund;
    return ListTile(
      dense: true,
      leading: Icon(
        switch (m.type) {
          CashMovementType.open => Icons.lock_open_rounded,
          CashMovementType.close => Icons.lock_rounded,
          CashMovementType.sale => Icons.shopping_bag_rounded,
          CashMovementType.refund => Icons.undo_rounded,
          CashMovementType.cashIn => Icons.add_circle_outline_rounded,
          CashMovementType.cashOut => Icons.remove_circle_outline_rounded,
        },
        color: isOut ? AppColors.danger : AppColors.amber,
      ),
      title: Text(_cashMovementLabels[m.type] ?? m.type.name),
      subtitle: Text([
        if (m.reason.isNotEmpty) m.reason,
        DateX.hm.format(m.createdAt),
      ].join(' • ')),
      trailing: MoneyText(
        isOut ? -m.amountKurus : m.amountKurus,
        color: isOut ? AppColors.danger : null,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------- Z raporu ----------------

Future<void> showZReport(BuildContext context, CashSession s) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => _ZReport(session: s),
  );
}

class _ZReport extends StatelessWidget {
  final CashSession session;
  const _ZReport({required this.session});

  @override
  Widget build(BuildContext context) {
    final diff = session.differenceKurus ?? 0;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('Z RAPORU', style: t.titleLarge),
            ),
            Center(
              child: Text(
                '${DateX.dmyHm.format(session.openedAt)}  -  '
                '${session.closedAt != null ? DateX.dmyHm.format(session.closedAt!) : "-"}',
                style: t.bodySmall,
              ),
            ),
            const Divider(height: AppSpacing.xl),
            _r('Acilis bakiyesi', session.openingFloatKurus),
            _r('Toplam satis', session.totalSalesKurus),
            _r('  Nakit', session.cashSalesKurus),
            _r('  Kart', session.cardSalesKurus),
            _r('  Diger', session.otherSalesKurus),
            _r('Para girisi', session.cashInKurus),
            _r('Para cikisi', -session.cashOutKurus),
            const Divider(height: AppSpacing.xl),
            _r('Beklenen nakit', session.expectedCashKurus, strong: true),
            _r('Sayilan nakit', session.countedCashKurus, strong: true),
            _r('Fark', diff,
                strong: true,
                color: diff == 0
                    ? AppColors.success
                    : (diff > 0 ? AppColors.amber : AppColors.danger)),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _r(String label, int kurus,
      {bool strong = false, Color? color}) {
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
}

// ---------------- Gecmis vardiyalar ----------------

class CashHistoryScreen extends ConsumerWidget {
  const CashHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(cashHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gecmis Vardiyalar')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Hata: $e'),
        data: (list) {
          final closed = list.where((s) => !s.isOpen).toList();
          if (closed.isEmpty) {
            return const EmptyState(
                icon: Icons.history_rounded,
                message: 'Henuz kapatilmis vardiya yok.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: closed.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = closed[i];
              final diff = s.differenceKurus ?? 0;
              return ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: Text(DateX.dmy.format(s.openedAt)),
                subtitle: Text(
                    'Satis: ${Money.format(s.totalSalesKurus)} • Fark: ${Money.format(diff)}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showZReport(context, s),
              );
            },
          );
        },
      ),
    );
  }
}
