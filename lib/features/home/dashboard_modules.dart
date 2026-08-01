import 'package:flutter/material.dart';

import '../accounting/accounting_screen.dart';
import '../cash/cash_screen.dart';
import '../catalog/products_screen.dart';
import '../courier/courier_hub_screen.dart';
import '../customers/customers_screen.dart';
import '../employees/employees_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../platform/platform_inbox_screen.dart';
import '../reports/reports_screen.dart';
import '../sales/sales_hub_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/stock_screen.dart';
import '../tables/tables_screen.dart';

/// Panelde (dashboard) yer alabilecek bir modul.
class DashboardModule {
  final String key;
  final String label;
  final IconData icon;
  final Widget Function() build;
  const DashboardModule(this.key, this.label, this.icon, this.build);
}

/// Tum moduller (panel kartlari + hizli erisim icin ortak katalog).
final List<DashboardModule> dashboardModules = [
  DashboardModule('sales', 'Satis', Icons.point_of_sale_rounded,
      () => const SalesHubScreen()),
  DashboardModule('tables', 'Masalar', Icons.table_restaurant_rounded,
      () => const TablesScreen()),
  DashboardModule('kitchen', 'Mutfak', Icons.soup_kitchen_rounded,
      () => const KitchenScreen()),
  DashboardModule(
      'products', 'Urunler', Icons.fastfood_rounded, () => const ProductsScreen()),
  DashboardModule('stock', 'Stok', Icons.inventory_2_rounded,
      () => const StockScreen()),
  DashboardModule('cash', 'Kasa', Icons.account_balance_wallet_rounded,
      () => const CashScreen()),
  DashboardModule('customers', 'Musteriler', Icons.people_alt_rounded,
      () => const CustomersScreen()),
  DashboardModule('employees', 'Personeller', Icons.badge_rounded,
      () => const EmployeesScreen()),
  DashboardModule('courier', 'Kurye', Icons.delivery_dining_rounded,
      () => const CourierHubScreen()),
  DashboardModule('platform', 'Platform', Icons.storefront_rounded,
      () => const PlatformInboxScreen()),
  DashboardModule('accounting', 'Muhasebe', Icons.calculate_rounded,
      () => const AccountingScreen()),
  DashboardModule('reports', 'Raporlar', Icons.insights_rounded,
      () => const ReportsScreen()),
  DashboardModule('settings', 'Ayarlar', Icons.settings_rounded,
      () => const SettingsScreen()),
];

final Map<String, DashboardModule> dashboardModuleMap = {
  for (final m in dashboardModules) m.key: m
};
