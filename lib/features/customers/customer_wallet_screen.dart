import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/people_collections.dart';

class CustomerWalletScreen extends ConsumerStatefulWidget {
  final int customerId;
  const CustomerWalletScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends ConsumerState<CustomerWalletScreen> {
  Customer? _customer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    final isar = ref.read(isarProvider);
    final customer = await isar.customers.get(widget.customerId);
    if (mounted) {
      setState(() {
        _customer = customer;
        _loading = false;
      });
    }
  }

  Future<void> _addBalanceDialog() async {
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_customer?.fullName} - Cüzdana Bakiye Yükle'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Yüklenecek Tutar (TL)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bakiye Yükle')),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final amount = Money.parse(ctrl.text);
      if (amount <= 0) return;

      final isar = ref.read(isarProvider);
      await isar.writeTxn(() async {
        _customer!.walletBalanceKurus += amount;
        _customer!.updatedAt = DateTime.now();
        await isar.customers.put(_customer!);
      });

      await _loadCustomer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cüzdana bakiye başarıyla yüklendi.'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _customer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_customer!.fullName} - Cüzdan ve Puan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Bakiye ve Puan Kartı
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          const Text('Cüzdan Bakiyesi', style: TextStyle(color: AppColors.dTextDim)),
                          const SizedBox(height: 8),
                          MoneyText(_customer!.walletBalanceKurus, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          const Text('Sadakat Puanı', style: TextStyle(color: AppColors.dTextDim)),
                          const SizedBox(height: 8),
                          Text('${_customer!.loyaltyPoints} Puan', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.amber)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // İşlem Butonları
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addBalanceDialog,
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: const Text('Cüzdana Para Yükle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}