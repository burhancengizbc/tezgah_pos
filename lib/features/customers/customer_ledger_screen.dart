import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/people_collections.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final int customerId;
  const CustomerLedgerScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  Customer? _customer;
  List<CustomerTransaction> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = ref.read(isarProvider);
    final customer = await isar.customers.get(widget.customerId);
    final txs = await isar.customerTransactions
        .filter()
        .customerIdEqualTo(widget.customerId)
        .sortByCreatedAtDesc()
        .findAll();

    if (mounted) {
      setState(() {
        _customer = customer;
        _transactions = txs;
        _loading = false;
      });
    }
  }

  // Ödeme Al (Veresiye Kapatma) Dialogu
  Future<void> _receivePayment() async {
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Elden Tahsilat');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_customer?.fullName} - Ödeme Al'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tahsil Edilen Tutar (TL)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Açıklama / Not'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tahsil Et')),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final amount = Money.parse(ctrl.text);
      if (amount <= 0) return;

      final isar = ref.read(isarProvider);
      final tx = CustomerTransaction()
        ..customerId = widget.customerId
        ..type = CustomerTxType.payment
        ..amountKurus = amount
        ..note = noteCtrl.text.trim();

      await isar.writeTxn(() async {
        await isar.customerTransactions.put(tx);
        // Müşterinin toplam harcama/bakiye güncellenebilir
        _customer!.totalSpendKurus = (_customer!.totalSpendKurus - amount).clamp(0, 999999999);
        await isar.customers.put(_customer!);
      });

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tahsilat başarıyla kaydedildi.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _customer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Toplam bakiye hesaplama (Borçlar - Ödemeler)
    int totalDebtKurus = 0;
    for (final t in _transactions) {
      if (t.type == CustomerTxType.debt) {
        totalDebtKurus += t.amountKurus;
      } else {
        totalDebtKurus -= t.amountKurus;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_customer!.fullName} - Cari Hesap'),
        actions: [
          IconButton(
            tooltip: 'Ödeme Al',
            icon: const Icon(Icons.payments_outlined, color: AppColors.success),
            onPressed: _receivePayment,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bakiye Özeti Kartı
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Güncel Bakiye / Borç', style: TextStyle(color: AppColors.dTextDim)),
                    const SizedBox(height: 4),
                    MoneyText(totalDebtKurus, style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: totalDebtKurus > 0 ? AppColors.danger : AppColors.success,
                    )),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _receivePayment,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('Ödeme Al'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Hareket Geçmişi Listesi
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text('Henüz cari hareket bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _transactions.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final tx = _transactions[i];
                      final isDebt = tx.type == CustomerTxType.debt;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDebt ? AppColors.danger.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2),
                          child: Icon(
                            isDebt ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: isDebt ? AppColors.danger : AppColors.success,
                          ),
                        ),
                        title: Text(tx.note.isEmpty ? (isDebt ? 'Veresiye Satış' : 'Tahsilat / Ödeme') : tx.note),
                        subtitle: Text('${tx.createdAt.day}.${tx.createdAt.month}.${tx.createdAt.year} - ${tx.createdAt.hour}:${tx.createdAt.minute}'),
                        trailing: MoneyText(
                          tx.amountKurus,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDebt ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}