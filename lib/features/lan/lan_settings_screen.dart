import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'lan_controller.dart';

class LanSettingsScreen extends ConsumerStatefulWidget {
  const LanSettingsScreen({super.key});

  @override
  ConsumerState<LanSettingsScreen> createState() => _LanSettingsScreenState();
}

class _LanSettingsScreenState extends ConsumerState<LanSettingsScreen> {
  String? _ip;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final ip = await ref.read(lanControllerProvider).wifiIp();
    if (mounted) setState(() => _ip = ip);
  }

  Future<void> _save(void Function(dynamic s) mutate,
      {bool restart = false}) async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.getSettings();
    mutate(s);
    await repo.saveSettings(s);
    if (restart) await ref.read(lanControllerProvider).restart();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStreamProvider).value;
    final lan = ref.read(lanControllerProvider);
    final enabled = settings?.lanServerEnabled ?? false;
    final token = settings?.lanPairToken ?? '';
    final port = settings?.lanServerPort ?? 8787;

    return Scaffold(
      appBar: AppBar(title: const Text('Yerel Ag & Moduller')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Tezgah, ayni WiFi/yerel agda bir sunucu acar. Telefondaki "Tezgah Cagri" '
            've "Tezgah Kurye" uygulamalari buna baglanir. Internet/ bulut kullanilmaz.',
            style: TextStyle(color: AppColors.dTextDim),
          ),
          const SizedBox(height: AppSpacing.lg),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yerel ag sunucusu'),
            subtitle: Text(lan.isRunning ? 'Calisiyor' : 'Kapali'),
            value: enabled,
            onChanged: (v) async {
              await _save((s) => s.lanServerEnabled = v, restart: false);
              if (v) {
                await ref.read(lanControllerProvider).ensureToken();
                await ref.read(lanControllerProvider).start();
              } else {
                await ref.read(lanControllerProvider).stop();
              }
              if (mounted) setState(() {});
            },
          ),

          if (enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Baglanti Bilgileri',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    _info('Sunucu adresi (IP)', _ip ?? 'WiFi bulunamadi'),
                    _info('Port', '$port'),
                    Row(
                      children: [
                        Expanded(child: _info('Eslesme kodu', token.isEmpty ? '-' : token)),
                        IconButton(
                          tooltip: 'Kopyala',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: token.isEmpty
                              ? null
                              : () {
                                  Clipboard.setData(ClipboardData(text: token));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Kod kopyalandi')));
                                },
                        ),
                        TextButton(
                          onPressed: () async {
                            await _save((s) => s.lanPairToken = '');
                            await ref.read(lanControllerProvider).ensureToken();
                            await ref.read(lanControllerProvider).restart();
                            if (mounted) setState(() {});
                          },
                          child: const Text('Yenile'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Companion uygulamada bu adres, port ve eslesme kodunu girin.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: AppSpacing.xxl),

            Text('Moduller', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gelen arama aktarimi (Cagri)'),
              subtitle: const Text(
                  'Telefondaki Cagri uygulamasindan gelen numarayi kabul et.'),
              value: settings?.lanCallerIdEnabled ?? false,
              onChanged: (v) => _save((s) => s.lanCallerIdEnabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kurye modulu'),
              subtitle: const Text('Siparisleri kuryeye atama ve takip.'),
              value: settings?.courierModuleEnabled ?? false,
              onChanged: (v) => _save((s) => s.courierModuleEnabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Platform siparisleri'),
              subtitle: const Text(
                  'Yemeksepeti/Getir vb. siparis gelen kutusu (yerel alim ucu).'),
              value: settings?.platformOrdersEnabled ?? false,
              onChanged: (v) => _save((s) => s.platformOrdersEnabled = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.dTextDim)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      );
}
