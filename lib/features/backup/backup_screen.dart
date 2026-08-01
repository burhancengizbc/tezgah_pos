import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_x.dart';
import '../../data/collections/delivery_collections.dart' as delivery;

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final path = await ref.read(backupServiceProvider).createBackup();
      if (!mounted) return;
      await Share.shareXFiles([XFile(path)],
          text: 'Tezgah POS yedegi', subject: 'Tezgah POS Yedek');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yedek olusturuldu.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Yedek hatasi: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        title: const Text('Geri yukle?'),
        content: const Text(
          'Bu islem MEVCUT TUM VERILERI siler ve yedektekiyle degistirir. '
          'Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Geri Yukle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final res = await ref.read(backupServiceProvider).restoreFromZip(path);
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
      if (res.ok) {
        showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Geri yuklendi'),
            content: const Text(
                'Veriler geri yuklendi. Degisikliklerin tam yansimasi icin '
                'uygulamayi kapatip yeniden acmaniz onerilir.'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Tamam')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStreamProvider).value;
    final last = settings?.lastBackupAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Yedekleme')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yedek Al',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Tum veriler (urunler, siparisler, kasa, muhasebe, '
                        'musteriler ve urun gorselleri) tek bir .zip dosyasina '
                        'aktarilir ve paylasilir.',
                      ),
                      if (last != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Son yedek: ${DateX.dmyHm.format(last)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _busy ? null : _backup,
                        icon: const Icon(Icons.backup_rounded),
                        label: const Text('Yedek Al ve Paylas'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Geri Yukle',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Daha once alinmis bir .zip yedegi secip geri yukleyin. '
                        'Dikkat: mevcut tum veriler silinir.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('Yedekten Geri Yukle'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
