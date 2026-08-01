import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/business_collections.dart';

class CashSessionScreen extends ConsumerStatefulWidget {
  const CashSessionScreen({super.key});

  @override
  ConsumerState<CashSessionScreen> createState() => _CashSessionScreenState();
}

class _CashSessionScreenState extends ConsumerState<CashSessionScreen> {
  bool _loading = true;
  CashSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    final isar = ref.read(isarProvider);
    final active = await isar.cashSessions
        .filter()
        .statusEqualTo(CashSessionStatus.open)
        .findFirst();

    if (mounted) {
      setState(() {
        _activeSession = active;
        _loading = false;
      });
    }
  }

  Future<void> _openRegisterDialog() async {
    final ctrl = TextEditingController(text: '1000'); // Varsayılan kasa açılış parası

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kasayı Aç (Vardiya Başlat)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Açılış Nakit Tutarı (Devir - TL)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kasayı Aç')),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final openingAmount = Money.parse(ctrl.text);
      final emp = ref.read(currentEmployeeProvider);

      final isar = ref.read(isarProvider);
      final session = CashSession()
        ..employeeId = emp?.id ?? 0
        ..employeeName = emp?.fullName ?? 'Yönetici'
        ..openingAmountKurus = openingAmount
        ..status = CashSessionStatus.open
        ..openedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.cashSessions.put(session);
      });

      await _checkActiveSession();
    }
  }

  Future<void> _closeRegisterDialog() async {
    if (_activeSession == null) return;
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kasayı Kapat (Z-Raporu / Sayım)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lütfen kasadaki toplam nakit parayı sayıp girin:'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Sayılan Nakit (TL)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Kasayı Kapat'),
          ),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final closingAmount = Money.parse(ctrl.text);
      final isar = ref.read(isarProvider);

      await isar.writeTxn(() async {
        _activeSession!.closingAmountKurus = closingAmount;
        _activeSession!.status = CashSessionStatus.closed;
        _activeSession!.closedAt = DateTime.now();
        await isar.cashSessions.put(_activeSession!);
      });

      await _checkActiveSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kasa vardiyası başarıyla kapatıldı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasa ve Vardiya Yönetimi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _activeSession == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_open_rounded, size: 64, color: AppColors.amber),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Şu anda açık bir kasa vardiyası bulunmuyor.', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _openRegisterDialog,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Yeni Vardiya Başlat (Kasa Aç)'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.between,
                            children: [
                              const Text('Aktif Vardiya Durumu', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                              Chip(label: Text('Açık • ${_activeSession!.employeeName}')),
                            ],
                          ),
                          const Divider(height: 24),
                          _rowInfo('Açılış Zamanı:', '${_activeSession!.openedAt.hour}:${_activeSession!.openedAt.minute}'),
                          const SizedBox(height: 8),
                          _rowInfo('Açılış Nakit (Devir):', Money.format(_activeSession!.openingAmountKurus)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _closeRegisterDialog,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Vardiyayı Kapat ve Kasa Sayımı Yap'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _rowInfo(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.dTextDim)),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}