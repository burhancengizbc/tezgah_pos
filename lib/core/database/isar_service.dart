import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/collections/business_collections.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/finance_collections.dart';
import '../../data/collections/inventory_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/collections/delivery_collections.dart' as delivery;

class IsarService {
  static Isar? _instance;

  static Future<Isar> init() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();

    _instance = await Isar.open(
      [
        BusinessProfileSchema,
        AppSettingsSchema,
        ReceiptCounterSchema,
        AuditLogSchema,
        CategorySchema,
        ProductSchema,
        StockMovementSchema,
        CustomerSchema,
        SupplierSchema,
        DiningTableSchema,
        EmployeeSchema,
        OrderSchema,
        OrderLineSchema,
        PaymentSchema,
        CashSessionSchema,
        CashMovementSchema,
        AccountingEntrySchema,
        IngredientSchema,
        RawMaterialSchema,
        StockTakeSchema,
        SemiFinishedProductSchema,
        KitchenStationSchema,
        DepartmentSchema,
        CampaignRuleSchema,
        delivery.CourierSchema,
        delivery.DeliverySchema,
        delivery.PlatformOrderSchema,
      ],
      directory: dir.path,
      inspector: true,
    );

    return _instance!;
  }

  static Isar get db {
    if (_instance == null) {
      throw Exception('IsarService initialized edilmedi!');
    }
    return _instance!;
  }

  // Servislerin 'isarService.isar' şeklinde erişebilmesi için instance getter
  Isar get isar => db;
}