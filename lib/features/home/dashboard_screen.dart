import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart'; 

import '../../core/providers/core_providers.dart'; 
import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/theme/ui_prefs.dart';
import '../../data/collections/sales_collections.dart'; 
import 'dashboard_modules.dart';
import '../sales/widgets/void_approvals_sheet.dart';
import '../../data/enums/app_enums.dart';



class _Tile {
  String key;
  int span; // 1, 2 veya 3 sutun
  _Tile(this.key, this.span);
}

/// Windows oncelikli, kullanici-ozellestirilebilir panel.
/// Duzenle modunda: basili tut-surukle ile yeniden sirala, boyutlandir (1/2/3),
/// gizle. Duzen kullanici basina kaydedilir.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<_Tile> _items = [];
  bool _edit = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    _items = _parse(s.dashboardLayout);
    if (mounted) setState(() => _loaded = true);
  }

  List<_Tile> _parse(String json) {
    if (json.trim().isNotEmpty) {
      try {
        final list = (jsonDecode(json) as List)
            .map((e) => _Tile(
                  (e['key'] ?? '').toString(),
                  ((e['span'] as num?)?.toInt() ?? 1).clamp(1, 3),
                ))
            .where((t) => dashboardModuleMap.containsKey(t.key))
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return _defaultLayout();
  }

  List<_Tile> _defaultLayout() => [
        for (final m in dashboardModules)
          _Tile(m.key, m.key == 'sales' ? 2 : 1),
      ];

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.getSettings();
    s.dashboardLayout =
        jsonEncode([for (final t in _items) {'key': t.key, 'span': t.span}]);
    await repo.saveSettings(s);
  }

  void _move(int from, int to) {
    if (from == to || from < 0 || from >= _items.length) return;
    final item = _items.removeAt(from);
    final target = to.clamp(0, _items.length);
    _items.insert(target, item);
    setState(() {});
    _save();
  }

  void _cycleSize(int i) {
    _items[i].span = _items[i].span >= 3 ? 1 : _items[i].span + 1;
    setState(() {});
    _save();
  }

  void _hide(int i) {
    _items.removeAt(i);
    setState(() {});
    _save();
  }

  void _addModule(String key) {
    if (_items.any((t) => t.key == key)) return;
    _items.add(_Tile(key, 1));
    setState(() {});
    _save();
  }

  void _reset() {
    _items = _defaultLayout();
    setState(() {});
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // O an giriş yapmış olan personeli alıyoruz
    final emp = ref.watch(currentEmployeeProvider);

    // Yetki Kontrol Motoru (Hangi modüllere izni var?)
    bool hasAccess(String key) {
      if (emp == null) return true; // Giriş yapılmamışsa (Geliştirici modu) açık
      if (emp.role == EmployeeRole.admin || emp.role == EmployeeRole.manager) return true;

      // Ayarlar, Yazıcılar, Ürün ve Kullanıcı yönetimi
      if (['settings', 'printers', 'users', 'catalog', 'categories', 'hardware'].contains(key)) return emp.canAccessSettings;
      
      // Muhasebe, Z-Raporu, Giderler, Kasa
      if (['reports', 'vault', 'expenses', 'z_report', 'end_of_day', 'ledger'].contains(key)) return emp.canViewGeneralReports;

      return true; // Masalar, Siparişler, KDS, Paket Servis garsona açıktır.
    }

    // Sadece yetkililer veya ayar izni olanlar ana ekranı düzenleyebilir
    final canEdit = emp == null || emp.role == EmployeeRole.admin || emp.role == EmployeeRole.manager || emp.canAccessSettings;
    
    // Yetkisiz biri bir şekilde düzenle modunda kalmışsa kapat
    if (!canEdit && _edit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _edit = false));
    }

    final hidden = dashboardModules
        .where((m) => !_items.any((t) => t.key == m.key) && hasAccess(m.key))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel'),
        actions: [
          // Sadece patron veya yönetici/ayar yetkisi olanlar bildirim zilini görür
          if (emp == null || emp.role == EmployeeRole.admin || emp.role == EmployeeRole.manager || emp.canAccessSettings)
            IconButton(
              tooltip: 'İptal Onayları',
              icon: FutureBuilder<List<OrderLine>>(
                future: ref.read(isarProvider).orderLines.filter().isVoidPendingEqualTo(true).findAll(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.notifications_active_outlined),
                  );
                },
              ),
              onPressed: () async {
                await VoidApprovalsSheet.show(context);
                setState(() {}); // Ekrandan dönünce listeyi yenile
              },
            ),

          IconButton(
            tooltip: 'Kilitle / Çıkış Yap',
            icon: const Icon(Icons.lock_person_outlined),
            onPressed: () {
              ref.read(currentEmployeeProvider.notifier).state = null;
            },
          ),
          if (_edit && hidden.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Modul ekle',
              onSelected: _addModule,
              itemBuilder: (_) => [
                for (final m in hidden)
                  PopupMenuItem(
                      value: m.key,
                      child: Row(children: [
                        Icon(m.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(m.label),
                      ])),
              ],
            ),
          if (_edit)
            IconButton(
              tooltip: 'Varsayilana dondur',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: _reset,
            ),
          if (canEdit) // Sadece yetkisi olanlar düzenle butonunu görebilir
            TextButton.icon(
              onPressed: () => setState(() => _edit = !_edit),
              icon: Icon(_edit ? Icons.check_rounded : Icons.tune_rounded),
              label: Text(_edit ? 'Bitti' : 'Duzenle'),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final w = constraints.maxWidth - AppSpacing.lg * 2;
          final dc = Breakpoints.of(context);
          final target = dc == DeviceClass.desktop
              ? 168.0
              : (dc == DeviceClass.tablet ? 150.0 : 112.0);
          var cols = (w / (target + gap)).floor();
          cols = cols.clamp(2, 6);
          final unit = (w - (cols - 1) * gap) / cols;
          final height = dc == DeviceClass.phone ? 112.0 : 124.0;

          double tileWidth(int span) {
            final s = span.clamp(1, cols);
            return s * unit + (s - 1) * gap;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_edit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Basili tutup surukleyerek tasi • boyut icin kareye, '
                      'gizlemek icin X\'e dokun',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      if (hasAccess(_items[i].key)) // Sadece yetkisi olan modülleri bas (veriyi silme, sadece gizle)
                        _buildTile(i, tileWidth(_items[i].span), height),
                  ],
                ),
                if (_items.where((t) => hasAccess(t.key)).isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Center(
                      child: Text('Görüntülenecek modül yok veya yetkiniz kısıtlı.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTile(int i, double width, double height) {
    final m = dashboardModuleMap[_items[i].key]!;
    final card = _TileCard(module: m, edit: _edit);

    if (!_edit) {
      return SizedBox(
        width: width,
        height: height,
        child: GestureDetector(
          onLongPress: () => setState(() => _edit = true),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => m.build())),
            child: card,
          ),
        ),
      );
    }

    // Duzenle modu: surukle-birak hedefi + tasinabilir + kontroller
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != i,
      onAcceptWithDetails: (d) => _move(d.data, i),
      builder: (context, candidate, _) {
        final highlight = candidate.isNotEmpty;
        return SizedBox(
          width: width,
          height: height,
          child: LongPressDraggable<int>(
            data: i,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                  width: width, height: height, child: _TileCard(module: m, edit: false)),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: card),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.rLg),
                      border: Border.all(
                        color: highlight ? AppColors.amber : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: card,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Row(
                    children: [
                      _miniBtn(Icons.aspect_ratio_rounded, () => _cycleSize(i),
                          '${_items[i].span}x'),
                      const SizedBox(width: 4),
                      _miniBtn(Icons.close_rounded, () => _hide(i), null),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap, String? badge) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (badge != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(badge,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            Icon(icon, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  final DashboardModule module;
  final bool edit;
  const _TileCard({required this.module, required this.edit});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
              ),
              child: Icon(module.icon, color: accent),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(module.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}