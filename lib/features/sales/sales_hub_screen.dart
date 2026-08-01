import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_x.dart';
import '../../data/enums/app_enums.dart';
import '../shared/widgets.dart';
import 'sales_screen.dart';

class SalesHubScreen extends ConsumerWidget {
  const SalesHubScreen({super.key});

  Future<void> _newPackage(BuildContext context, WidgetRef ref) async {
    final order = await ref
        .read(orderRepositoryProvider)
        .openOrder(type: OrderType.package);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SalesScreen(orderId: order.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStreamProvider).value;
    final isTableService = settings?.isTableServiceEnabled ?? true;
    final openAsync = ref.watch(openPackageOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isTableService ? 'Paket / Gel-Al Satışları' : 'Hızlı Satış (Tezgah)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newPackage(context, ref),
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(isTableService ? 'Yeni Paket / Gel-Al' : 'Hızlı Fiş Aç / Satış Yap'),
      ),
      body: openAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyState(
              icon: Icons.point_of_sale_outlined,
              message: isTableService
                  ? 'Açık paket adisyon yok.\nYeni adisyon için alttaki butonu kullanın.'
                  : 'Aktif hızlı satış fişi yok.\nTek dokunuşla hemen yeni fiş açabilirsiniz.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final o = orders[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.takeout_dining_outlined),
                  title: Text('Fiş / Paket #${o.receiptNo}'),
                  subtitle: Text(DateX.dmyHm.format(o.createdAt)),
                  trailing: MoneyText(o.totalKurus,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => SalesScreen(orderId: o.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}