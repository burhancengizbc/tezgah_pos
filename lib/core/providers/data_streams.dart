import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../data/collections/business_collections.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/delivery_collections.dart' as delivery;
import '../../data/collections/finance_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../constants/app_constants.dart';
import 'core_providers.dart';

/// Ayarlar (canli).
final settingsStreamProvider = StreamProvider<AppSettings>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<AppSettings>()
      .watchObject(AppConstants.appSettingsId, fireImmediately: true)
      .map((e) => e ?? (AppSettings()..id = AppConstants.appSettingsId));
});

/// Aktif masalar (canli).
final tablesStreamProvider = StreamProvider<List<DiningTable>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<DiningTable>()
      .filter()
      .isDeletedEqualTo(false)
      .isActiveEqualTo(true)
      .sortBySortOrder()
      .watch(fireImmediately: true);
});

/// Aktif kategoriler (canli).
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<Category>()
      .filter()
      .isDeletedEqualTo(false)
      .isActiveEqualTo(true)
      .sortBySortOrder()
      .watch(fireImmediately: true);
});

/// Tum kategoriler (yonetim ekrani).
final allCategoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<Category>()
      .filter()
      .isDeletedEqualTo(false)
      .sortBySortOrder()
      .watch(fireImmediately: true);
});

/// Kategoriye gore urunler (satis ekrani).
final productsByCategoryProvider =
    StreamProvider.family<List<Product>, int>((ref, categoryId) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<Product>()
      .filter()
      .isDeletedEqualTo(false)
      .isActiveEqualTo(true)
      .categoryIdEqualTo(categoryId)
      .sortBySortOrder()
      .watch(fireImmediately: true);
});

/// Tum urunler (yonetim ekrani).
final allProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<Product>()
      .filter()
      .isDeletedEqualTo(false)
      .sortByName()
      .watch(fireImmediately: true);
});

/// Tek siparis (canli).
final orderStreamProvider =
    StreamProvider.family<Order?, int>((ref, orderId) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<Order>()
      .watchObject(orderId, fireImmediately: true);
});

/// Bir siparisin satirlari (canli).
final orderLinesStreamProvider =
    StreamProvider.family<List<OrderLine>, int>((ref, orderId) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<OrderLine>()
      .filter()
      .orderIdEqualTo(orderId)
      .sortByCreatedAt()
      .watch(fireImmediately: true);
});

/// Acik paket adisyonlari (canli).
final openPackageOrdersProvider = StreamProvider<List<Order>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<Order>()
      .filter()
      .statusEqualTo(OrderStatus.open)
      .typeEqualTo(OrderType.package)
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
});

/// Acik kasa vardiyasi (canli). Yoksa null.
final openCashSessionProvider = StreamProvider<CashSession?>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<CashSession>()
      .filter()
      .isOpenEqualTo(true)
      .sortByOpenedAtDesc()
      .watch(fireImmediately: true)
      .map((l) => l.isEmpty ? null : l.first);
});

/// Bir vardiyanin kasa hareketleri (canli).
final cashMovementsProvider =
    StreamProvider.family<List<CashMovement>, int>((ref, sessionId) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<CashMovement>()
      .filter()
      .sessionIdEqualTo(sessionId)
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
});

/// Gecmis vardiyalar (canli) - gun sonu Z raporlari icin.
final cashHistoryProvider = StreamProvider<List<CashSession>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<CashSession>()
      .where()
      .sortByOpenedAtDesc()
      .limit(60)
      .watch(fireImmediately: true);
});

/// Tum muhasebe kayitlari (canli, silinmemis). Donem filtresi ekranda yapilir.
final accountingEntriesProvider = StreamProvider<List<AccountingEntry>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<AccountingEntry>()
      .filter()
      .isDeletedEqualTo(false)
      .sortByDateDesc()
      .watch(fireImmediately: true);
});

/// Aktif kuryeler (canli).
final couriersProvider = StreamProvider<List<delivery.Courier>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<delivery.Courier>()
      .filter()
      .isDeletedEqualTo(false)
      .sortByName()
      .watch(fireImmediately: true);
});

/// Aktif teslimatlar (teslim/iptal disindakiler, canli).
final activeDeliveriesProvider = StreamProvider<List<delivery.Delivery>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<delivery.Delivery>()
      .filter()
      .not()
      .group((q) => q
          .statusEqualTo(DeliveryStatus.delivered)
          .or()
          .statusEqualTo(DeliveryStatus.cancelled))
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
});

/// Platform siparisleri (son 100, canli).
final platformOrdersProvider = StreamProvider<List<delivery.PlatformOrder>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<delivery.PlatformOrder>()
      .where()
      .sortByCreatedAtDesc()
      .limit(100)
      .watch(fireImmediately: true);
});

/// Mutfak (KDS): aktif satirlar (queued + ready), eskiden yeniye.
final kitchenLinesProvider = StreamProvider<List<OrderLine>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<OrderLine>()
      .filter()
      .isVoidEqualTo(false)
      .group((q) => q
          .kitchenStatusEqualTo(KitchenStatus.queued)
          .or()
          .kitchenStatusEqualTo(KitchenStatus.ready))
      .sortBySentToKitchenAt()
      .watch(fireImmediately: true);
});

final activeEmployeesProvider = StreamProvider<List<Employee>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar
      .collection<Employee>()
      .filter()
      .isDeletedEqualTo(false)
      .isActiveEqualTo(true)
      .sortByLastName()
      .watch(fireImmediately: true);
});