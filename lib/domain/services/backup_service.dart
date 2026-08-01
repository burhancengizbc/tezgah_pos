import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/collections/business_collections.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/finance_collections.dart';
import '../../data/collections/inventory_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/collections/delivery_collections.dart' as delivery;
import '../../data/enums/app_enums.dart';

/// Tum veriyi JSON + ZIP olarak disa/ice aktarir. Tamamen offline.
/// Yedek ZIP icinde: backup.json (tum koleksiyonlar) + images/ (urun gorselleri).
class BackupService {
  final Isar isar;
  BackupService(this.isar);

  static const int formatVersion = 1;

  // ---------------------------------------------------------------- EXPORT

  Future<String> createBackup({bool includeImages = true}) async {
    final data = <String, dynamic>{
      'businessProfile':
          (await isar.collection<BusinessProfile>().where().findAll())
              .map(_C.businessToMap)
              .toList(),
      'appSettings': (await isar.collection<AppSettings>().where().findAll())
          .map(_C.settingsToMap)
          .toList(),
      'receiptCounter':
          (await isar.collection<ReceiptCounter>().where().findAll())
              .map(_C.counterToMap)
              .toList(),
      'auditLog': (await isar.collection<AuditLog>().where().findAll())
          .map(_C.auditToMap)
          .toList(),
      'category': (await isar.collection<Category>().where().findAll())
          .map(_C.categoryToMap)
          .toList(),
      'product': (await isar.collection<Product>().where().findAll())
          .map(_C.productToMap)
          .toList(),
      'stockMovement':
          (await isar.collection<StockMovement>().where().findAll())
              .map(_C.stockToMap)
              .toList(),
      'customer': (await isar.collection<Customer>().where().findAll())
          .map(_C.customerToMap)
          .toList(),
      'diningTable': (await isar.collection<DiningTable>().where().findAll())
          .map(_C.tableToMap)
          .toList(),
      'order': (await isar.collection<Order>().where().findAll())
          .map(_C.orderToMap)
          .toList(),
      'orderLine': (await isar.collection<OrderLine>().where().findAll())
          .map(_C.lineToMap)
          .toList(),
      'payment': (await isar.collection<Payment>().where().findAll())
          .map(_C.paymentToMap)
          .toList(),
      'cashSession': (await isar.collection<CashSession>().where().findAll())
          .map(_C.sessionToMap)
          .toList(),
      'cashMovement': (await isar.collection<CashMovement>().where().findAll())
          .map(_C.cashMoveToMap)
          .toList(),
      'accountingEntry':
          (await isar.collection<AccountingEntry>().where().findAll())
              .map(_C.acctToMap)
              .toList(),
      'courier': (await isar.collection<delivery.Courier>().where().findAll())
          .map(_C.courierToMap)
          .toList(),
      'delivery': (await isar.collection<delivery.Delivery>().where().findAll())
          .map(_C.deliveryToMap)
          .toList(),
      'platformOrder':
          (await isar.collection<delivery.PlatformOrder>().where().findAll())
              .map(_C.platformToMap)
              .toList(),
    };

    final root = <String, dynamic>{
      'app': 'tezgah_pos',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };

    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(root));
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    if (includeImages) {
      final imgDir = await _imagesDir();
      if (await imgDir.exists()) {
        for (final entity in imgDir.listSync()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final name = 'images/${p.basename(entity.path)}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }
    }

    final zipBytes = ZipEncoder().encode(archive)!;
    final dir = await _backupsDir();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .replaceAll('T', '_')
        .substring(0, 19);
    final file = File(p.join(dir.path, 'tezgah_yedek_$stamp.zip'));
    await file.writeAsBytes(zipBytes);

    // lastBackupAt guncelle
    final settings = await isar.collection<AppSettings>().get(1);
    if (settings != null) {
      settings.lastBackupAt = DateTime.now();
      await isar.writeTxn(() => isar.collection<AppSettings>().put(settings));
    }

    return file.path;
  }

  // ---------------------------------------------------------------- IMPORT

  Future<({bool ok, String message})> restoreFromZip(String zipPath) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? jsonFile;
      final imageFiles = <ArchiveFile>[];
      for (final f in archive.files) {
        if (f.name == 'backup.json') {
          jsonFile = f;
        } else if (f.name.startsWith('images/') && f.isFile) {
          imageFiles.add(f);
        }
      }
      if (jsonFile == null) {
        return (ok: false, message: 'Gecersiz yedek: backup.json bulunamadi.');
      }

      final root = jsonDecode(utf8.decode(jsonFile.content as List<int>))
          as Map<String, dynamic>;
      if (root['app'] != 'tezgah_pos') {
        return (ok: false, message: 'Bu dosya bir Tezgah POS yedegi degil.');
      }
      final data = (root['data'] as Map).cast<String, dynamic>();

      // Once gorselleri geri yaz, basename -> yeni yol haritasi cikar.
      final imgDir = await _imagesDir();
      if (!await imgDir.exists()) await imgDir.create(recursive: true);
      final imageMap = <String, String>{};
      for (final f in imageFiles) {
        final base = p.basename(f.name);
        final dest = File(p.join(imgDir.path, base));
        await dest.writeAsBytes(f.content as List<int>);
        imageMap[base] = dest.path;
      }

      List<Map<String, dynamic>> rows(String key) =>
          ((data[key] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();

      await isar.writeTxn(() async {
        await isar.clear(); // tum koleksiyonlari temizle

        await isar
            .collection<BusinessProfile>()
            .putAll(rows('businessProfile').map(_C.businessFromMap).toList());
        await isar
            .collection<AppSettings>()
            .putAll(rows('appSettings').map(_C.settingsFromMap).toList());
        await isar
            .collection<ReceiptCounter>()
            .putAll(rows('receiptCounter').map(_C.counterFromMap).toList());
        await isar
            .collection<AuditLog>()
            .putAll(rows('auditLog').map(_C.auditFromMap).toList());
        await isar
            .collection<Category>()
            .putAll(rows('category').map(_C.categoryFromMap).toList());
        await isar.collection<Product>().putAll(
            rows('product').map((m) => _C.productFromMap(m, imageMap)).toList());
        await isar
            .collection<StockMovement>()
            .putAll(rows('stockMovement').map(_C.stockFromMap).toList());
        await isar
            .collection<Customer>()
            .putAll(rows('customer').map(_C.customerFromMap).toList());
        await isar
            .collection<DiningTable>()
            .putAll(rows('diningTable').map(_C.tableFromMap).toList());
        await isar
            .collection<Order>()
            .putAll(rows('order').map(_C.orderFromMap).toList());
        await isar
            .collection<OrderLine>()
            .putAll(rows('orderLine').map(_C.lineFromMap).toList());
        await isar
            .collection<Payment>()
            .putAll(rows('payment').map(_C.paymentFromMap).toList());
        await isar
            .collection<CashSession>()
            .putAll(rows('cashSession').map(_C.sessionFromMap).toList());
        await isar
            .collection<CashMovement>()
            .putAll(rows('cashMovement').map(_C.cashMoveFromMap).toList());
        await isar
            .collection<AccountingEntry>()
            .putAll(rows('accountingEntry').map(_C.acctFromMap).toList());
        await isar
            .collection<delivery.Courier>()
            .putAll(rows('courier').map(_C.courierFromMap).toList());
        await isar
            .collection<delivery.Delivery>()
            .putAll(rows('delivery').map(_C.deliveryFromMap).toList());
        await isar
            .collection<delivery.PlatformOrder>()
            .putAll(rows('platformOrder').map(_C.platformFromMap).toList());
      });

      return (ok: true, message: 'Yedek basariyla geri yuklendi.');
    } catch (e) {
      return (ok: false, message: 'Geri yukleme hatasi: $e');
    }
  }

  Future<Directory> _backupsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'images', 'products'));
  }
}

/// Serilestirme/deserilestirme yardimcilari (tum koleksiyonlar icin).
class _C {
  _C._();

  static int? _dt(DateTime? d) => d?.millisecondsSinceEpoch;
  static DateTime _date(dynamic v) =>
      v == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(v as int);
  static DateTime? _dateN(dynamic v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

  static T _enum<T extends Enum>(List<T> values, dynamic name, T def) =>
      values.firstWhere((e) => e.name == name, orElse: () => def);
  static T? _enumN<T extends Enum>(List<T> values, dynamic name) {
    if (name == null) return null;
    for (final e in values) {
      if (e.name == name) return e;
    }
    return null;
  }

  // BusinessProfile
  static Map<String, dynamic> businessToMap(BusinessProfile b) => {
        'id': b.id,
        'name': b.name,
        'phone': b.phone,
        'address': b.address,
        'taxOffice': b.taxOffice,
        'taxNumber': b.taxNumber,
        'logoPath': b.logoPath,
        'receiptFooter': b.receiptFooter,
        'createdAt': _dt(b.createdAt),
        'updatedAt': _dt(b.updatedAt),
      };
  static BusinessProfile businessFromMap(Map<String, dynamic> m) =>
      BusinessProfile()
        ..id = m['id'] as int
        ..name = m['name'] ?? ''
        ..phone = m['phone'] ?? ''
        ..address = m['address'] ?? ''
        ..taxOffice = m['taxOffice'] ?? ''
        ..taxNumber = m['taxNumber'] ?? ''
        ..logoPath = m['logoPath']
        ..receiptFooter = m['receiptFooter'] ?? ''
        ..createdAt = _date(m['createdAt'])
        ..updatedAt = _date(m['updatedAt']);

  // AppSettings
  static Map<String, dynamic> settingsToMap(AppSettings s) => {
        'id': s.id,
        'appLockEnabled': s.appLockEnabled,
        'appPinHash': s.appPinHash,
        'appPinSalt': s.appPinSalt,
        'adminPinHash': s.adminPinHash,
        'adminPinSalt': s.adminPinSalt,
        'autoLockEnabled': s.autoLockEnabled,
        'autoLockMinutes': s.autoLockMinutes,
        'printerMac': s.printerMac,
        'printerName': s.printerName,
        'paperSizeMm': s.paperSizeMm,
        'printAfterPayment': s.printAfterPayment,
        'receiptHeader': s.receiptHeader,
        'receiptFooter': s.receiptFooter,
        'callerIdEnabled': s.callerIdEnabled,
        'lanServerEnabled': s.lanServerEnabled,
        'lanServerPort': s.lanServerPort,
        'lanPairToken': s.lanPairToken,
        'courierModuleEnabled': s.courierModuleEnabled,
        'platformOrdersEnabled': s.platformOrdersEnabled,
        'lanCallerIdEnabled': s.lanCallerIdEnabled,
        'darkMode': s.darkMode,
        'currencySymbol': s.currencySymbol,
        'defaultVatRate': s.defaultVatRate,
        'lastBackupAt': _dt(s.lastBackupAt),
        'onboardingDone': s.onboardingDone,
        'updatedAt': _dt(s.updatedAt),
      };
  static AppSettings settingsFromMap(Map<String, dynamic> m) => AppSettings()
    ..id = m['id'] as int
    ..appLockEnabled = m['appLockEnabled'] ?? false
    ..appPinHash = m['appPinHash']
    ..appPinSalt = m['appPinSalt']
    ..adminPinHash = m['adminPinHash']
    ..adminPinSalt = m['adminPinSalt']
    ..autoLockEnabled = m['autoLockEnabled'] ?? true
    ..autoLockMinutes = m['autoLockMinutes'] ?? 5
    ..printerMac = m['printerMac']
    ..printerName = m['printerName']
    ..paperSizeMm = m['paperSizeMm'] ?? 80
    ..printAfterPayment = m['printAfterPayment'] ?? false
    ..receiptHeader = m['receiptHeader'] ?? ''
    ..receiptFooter = m['receiptFooter'] ?? ''
    ..callerIdEnabled = m['callerIdEnabled'] ?? false
    ..lanServerEnabled = m['lanServerEnabled'] ?? false
    ..lanServerPort = m['lanServerPort'] ?? 8787
    ..lanPairToken = m['lanPairToken'] ?? ''
    ..courierModuleEnabled = m['courierModuleEnabled'] ?? false
    ..platformOrdersEnabled = m['platformOrdersEnabled'] ?? false
    ..lanCallerIdEnabled = m['lanCallerIdEnabled'] ?? false
    ..darkMode = m['darkMode'] ?? true
    ..currencySymbol = m['currencySymbol'] ?? '\u20BA'
    ..defaultVatRate = (m['defaultVatRate'] as num?)?.toDouble() ?? 10.0
    ..lastBackupAt = _dateN(m['lastBackupAt'])
    ..onboardingDone = m['onboardingDone'] ?? false
    ..updatedAt = _date(m['updatedAt']);

  // ReceiptCounter
  static Map<String, dynamic> counterToMap(ReceiptCounter c) =>
      {'id': c.id, 'year': c.year, 'lastSeq': c.lastSeq};
  static ReceiptCounter counterFromMap(Map<String, dynamic> m) => ReceiptCounter()
    ..id = m['id'] as int
    ..year = m['year'] as int
    ..lastSeq = m['lastSeq'] as int;

  // AuditLog
  static Map<String, dynamic> auditToMap(AuditLog a) => {
        'id': a.id,
        'action': a.action.name,
        'entity': a.entity,
        'entityId': a.entityId,
        'detail': a.detail,
        'createdAt': _dt(a.createdAt),
      };
  static AuditLog auditFromMap(Map<String, dynamic> m) => AuditLog()
    ..id = m['id'] as int
    ..action = _enum(AuditAction.values, m['action'], AuditAction.create)
    ..entity = m['entity'] ?? ''
    ..entityId = m['entityId']
    ..detail = m['detail'] ?? ''
    ..createdAt = _date(m['createdAt']);

  // Category
  static Map<String, dynamic> categoryToMap(Category c) => {
        'id': c.id,
        'name': c.name,
        'sortOrder': c.sortOrder,
        'isActive': c.isActive,
        'colorValue': c.colorValue,
        'iconCodePoint': c.iconCodePoint,
        'isDeleted': c.isDeleted,
        'createdAt': _dt(c.createdAt),
        'updatedAt': _dt(c.updatedAt),
      };
  static Category categoryFromMap(Map<String, dynamic> m) => Category()
    ..id = m['id'] as int
    ..name = m['name'] ?? ''
    ..sortOrder = m['sortOrder'] ?? 0
    ..isActive = m['isActive'] ?? true
    ..colorValue = m['colorValue'] ?? 0xFF2A2A2E
    ..iconCodePoint = m['iconCodePoint'] ?? 0xe56c
    ..isDeleted = m['isDeleted'] ?? false
    ..createdAt = _date(m['createdAt'])
    ..updatedAt = _date(m['updatedAt']);

  // Embedded modifiers
  static Map<String, dynamic> modOptToMap(ModifierOption o) =>
      {'name': o.name, 'priceKurus': o.priceKurus};
  static ModifierOption modOptFromMap(Map<String, dynamic> m) => ModifierOption()
    ..name = m['name'] ?? ''
    ..priceKurus = m['priceKurus'] ?? 0;

  static Map<String, dynamic> modGroupToMap(ModifierGroup g) => {
        'name': g.name,
        'multiSelect': g.multiSelect,
        'required': g.required,
        'options': g.options.map(modOptToMap).toList(),
      };
  static ModifierGroup modGroupFromMap(Map<String, dynamic> m) => ModifierGroup()
    ..name = m['name'] ?? ''
    ..multiSelect = m['multiSelect'] ?? false
    ..required = m['required'] ?? false
    ..options = ((m['options'] as List?) ?? const [])
        .map((e) => modOptFromMap((e as Map).cast<String, dynamic>()))
        .toList();

  // Product
  static Map<String, dynamic> productToMap(Product pr) => {
        'id': pr.id,
        'name': pr.name,
        'categoryId': pr.categoryId,
        'salePriceKurus': pr.salePriceKurus,
        'costPriceKurus': pr.costPriceKurus,
        'barcode': pr.barcode,
        'description': pr.description,
        'imagePath': pr.imagePath,
        'isActive': pr.isActive,
        'stockType': pr.stockType.name,
        'stockQty': pr.stockQty,
        'minStock': pr.minStock,
        'sellByWeight': pr.sellByWeight,
        'vatRate': pr.vatRate,
        'sortOrder': pr.sortOrder,
        'modifierGroups': pr.modifierGroups.map(modGroupToMap).toList(),
        'isDeleted': pr.isDeleted,
        'createdAt': _dt(pr.createdAt),
        'updatedAt': _dt(pr.updatedAt),
      };
  static Product productFromMap(
      Map<String, dynamic> m, Map<String, String> imageMap) {
    final pr = Product()
      ..id = m['id'] as int
      ..name = m['name'] ?? ''
      ..categoryId = m['categoryId'] ?? 0
      ..salePriceKurus = m['salePriceKurus'] ?? 0
      ..costPriceKurus = m['costPriceKurus'] ?? 0
      ..barcode = m['barcode']
      ..description = m['description'] ?? ''
      ..isActive = m['isActive'] ?? true
      ..stockType = _enum(StockType.values, m['stockType'], StockType.unlimited)
      ..stockQty = (m['stockQty'] as num?)?.toDouble() ?? 0
      ..minStock = (m['minStock'] as num?)?.toDouble() ?? 0
      ..sellByWeight = m['sellByWeight'] ?? false
      ..vatRate = (m['vatRate'] as num?)?.toDouble() ?? 10.0
      ..sortOrder = m['sortOrder'] ?? 0
      ..modifierGroups = ((m['modifierGroups'] as List?) ?? const [])
          .map((e) => modGroupFromMap((e as Map).cast<String, dynamic>()))
          .toList()
      ..isDeleted = m['isDeleted'] ?? false
      ..createdAt = _date(m['createdAt'])
      ..updatedAt = _date(m['updatedAt']);
    final oldPath = m['imagePath'] as String?;
    if (oldPath != null && oldPath.isNotEmpty) {
      final base = p.basename(oldPath);
      pr.imagePath = imageMap[base] ?? oldPath;
    }
    return pr;
  }

  // StockMovement
  static Map<String, dynamic> stockToMap(StockMovement s) => {
        'id': s.id,
        'productId': s.productId,
        'type': s.type.name,
        'qty': s.qty,
        'balanceAfter': s.balanceAfter,
        'note': s.note,
        'refOrderId': s.refOrderId,
        'createdAt': _dt(s.createdAt),
      };
  static StockMovement stockFromMap(Map<String, dynamic> m) => StockMovement()
    ..id = m['id'] as int
    ..productId = m['productId'] ?? 0
    ..type = _enum(StockMovementType.values, m['type'], StockMovementType.adjust)
    ..qty = (m['qty'] as num?)?.toDouble() ?? 0
    ..balanceAfter = (m['balanceAfter'] as num?)?.toDouble() ?? 0
    ..note = m['note'] ?? ''
    ..refOrderId = m['refOrderId']
    ..createdAt = _date(m['createdAt']);

  // Customer
  static Map<String, dynamic> customerToMap(Customer c) => {
        'id': c.id,
        'firstName': c.firstName,
        'lastName': c.lastName,
        'phone': c.phone,
        'address': c.address,
        'note': c.note,
        'totalOrders': c.totalOrders,
        'totalSpendKurus': c.totalSpendKurus,
        'lastOrderAt': _dt(c.lastOrderAt),
        'isDeleted': c.isDeleted,
        'createdAt': _dt(c.createdAt),
        'updatedAt': _dt(c.updatedAt),
      };
  static Customer customerFromMap(Map<String, dynamic> m) => Customer()
    ..id = m['id'] as int
    ..firstName = m['firstName'] ?? ''
    ..lastName = m['lastName'] ?? ''
    ..phone = m['phone'] ?? ''
    ..address = m['address'] ?? ''
    ..note = m['note'] ?? ''
    ..totalOrders = m['totalOrders'] ?? 0
    ..totalSpendKurus = m['totalSpendKurus'] ?? 0
    ..lastOrderAt = _dateN(m['lastOrderAt'])
    ..isDeleted = m['isDeleted'] ?? false
    ..createdAt = _date(m['createdAt'])
    ..updatedAt = _date(m['updatedAt']);

  // DiningTable
  static Map<String, dynamic> tableToMap(DiningTable t) => {
        'id': t.id,
        'name': t.name,
        'colorValue': t.colorValue,
        'isActive': t.isActive,
        'status': t.status.name,
        'currentOrderId': t.currentOrderId,
        'sortOrder': t.sortOrder,
        'isDeleted': t.isDeleted,
        'createdAt': _dt(t.createdAt),
        'updatedAt': _dt(t.updatedAt),
      };
  static DiningTable tableFromMap(Map<String, dynamic> m) => DiningTable()
    ..id = m['id'] as int
    ..name = m['name'] ?? ''
    ..colorValue = m['colorValue'] ?? 0xFF2E7D32
    ..isActive = m['isActive'] ?? true
    ..status = _enum(TableStatus.values, m['status'], TableStatus.empty)
    ..currentOrderId = m['currentOrderId']
    ..sortOrder = m['sortOrder'] ?? 0
    ..isDeleted = m['isDeleted'] ?? false
    ..createdAt = _date(m['createdAt'])
    ..updatedAt = _date(m['updatedAt']);

  // Order
  static Map<String, dynamic> orderToMap(Order o) => {
        'id': o.id,
        'receiptNo': o.receiptNo,
        'type': o.type.name,
        'status': o.status.name,
        'tableId': o.tableId,
        'customerId': o.customerId,
        'cashSessionId': o.cashSessionId,
        'subtotalKurus': o.subtotalKurus,
        'vatTotalKurus': o.vatTotalKurus,
        'discountAmountKurus': o.discountAmountKurus,
        'totalKurus': o.totalKurus,
        'discountType': o.discountType.name,
        'discountValue': o.discountValue,
        'paidKurus': o.paidKurus,
        'note': o.note,
        'operatorName': o.operatorName,
        'createdAt': _dt(o.createdAt),
        'closedAt': _dt(o.closedAt),
        'updatedAt': _dt(o.updatedAt),
      };
  static Order orderFromMap(Map<String, dynamic> m) => Order()
    ..id = m['id'] as int
    ..receiptNo = m['receiptNo'] ?? 0
    ..type = _enum(OrderType.values, m['type'], OrderType.table)
    ..status = _enum(OrderStatus.values, m['status'], OrderStatus.open)
    ..tableId = m['tableId']
    ..customerId = m['customerId']
    ..cashSessionId = m['cashSessionId']
    ..subtotalKurus = m['subtotalKurus'] ?? 0
    ..vatTotalKurus = m['vatTotalKurus'] ?? 0
    ..discountAmountKurus = m['discountAmountKurus'] ?? 0
    ..totalKurus = m['totalKurus'] ?? 0
    ..discountType = _enum(DiscountType.values, m['discountType'], DiscountType.none)
    ..discountValue = (m['discountValue'] as num?)?.toDouble() ?? 0
    ..paidKurus = m['paidKurus'] ?? 0
    ..note = m['note'] ?? ''
    ..operatorName = m['operatorName']
    ..createdAt = _date(m['createdAt'])
    ..closedAt = _dateN(m['closedAt'])
    ..updatedAt = _date(m['updatedAt']);

  // SelectedModifier
  static Map<String, dynamic> selModToMap(SelectedModifier s) =>
      {'groupName': s.groupName, 'optionName': s.optionName, 'priceKurus': s.priceKurus};
  static SelectedModifier selModFromMap(Map<String, dynamic> m) =>
      SelectedModifier()
        ..groupName = m['groupName'] ?? ''
        ..optionName = m['optionName'] ?? ''
        ..priceKurus = m['priceKurus'] ?? 0;

  // OrderLine
  static Map<String, dynamic> lineToMap(OrderLine l) => {
        'id': l.id,
        'orderId': l.orderId,
        'productId': l.productId,
        'categoryId': l.categoryId,
        'productName': l.productName,
        'unitPriceKurus': l.unitPriceKurus,
        'costPriceKurus': l.costPriceKurus,
        'qty': l.qty,
        'vatRate': l.vatRate,
        'lineTotalKurus': l.lineTotalKurus,
        'modifiers': l.modifiers.map(selModToMap).toList(),
        'note': l.note,
        'isVoid': l.isVoid,
        'voidReason': l.voidReason,
        'isPaid': l.isPaid,
        'soldAt': _dt(l.soldAt),
        'cashSessionId': l.cashSessionId,
        'createdAt': _dt(l.createdAt),
      };
  static OrderLine lineFromMap(Map<String, dynamic> m) => OrderLine()
    ..id = m['id'] as int
    ..orderId = m['orderId'] ?? 0
    ..productId = m['productId'] ?? 0
    ..categoryId = m['categoryId'] ?? 0
    ..productName = m['productName'] ?? ''
    ..unitPriceKurus = m['unitPriceKurus'] ?? 0
    ..costPriceKurus = m['costPriceKurus'] ?? 0
    ..qty = (m['qty'] as num?)?.toDouble() ?? 1
    ..vatRate = (m['vatRate'] as num?)?.toDouble() ?? 10.0
    ..lineTotalKurus = m['lineTotalKurus'] ?? 0
    ..modifiers = ((m['modifiers'] as List?) ?? const [])
        .map((e) => selModFromMap((e as Map).cast<String, dynamic>()))
        .toList()
    ..note = m['note'] ?? ''
    ..isVoid = m['isVoid'] ?? false
    ..voidReason = m['voidReason']
    ..isPaid = m['isPaid'] ?? false
    ..soldAt = _dateN(m['soldAt'])
    ..cashSessionId = m['cashSessionId']
    ..createdAt = _date(m['createdAt']);

  // Payment
  static Map<String, dynamic> paymentToMap(Payment p) => {
        'id': p.id,
        'orderId': p.orderId,
        'method': p.method.name,
        'amountKurus': p.amountKurus,
        'note': p.note,
        'createdAt': _dt(p.createdAt),
      };
  static Payment paymentFromMap(Map<String, dynamic> m) => Payment()
    ..id = m['id'] as int
    ..orderId = m['orderId'] ?? 0
    ..method = _enum(PaymentMethod.values, m['method'], PaymentMethod.cash)
    ..amountKurus = m['amountKurus'] ?? 0
    ..note = m['note'] ?? ''
    ..createdAt = _date(m['createdAt']);

  // CashSession
  static Map<String, dynamic> sessionToMap(CashSession s) => {
        'id': s.id,
        'openedAt': _dt(s.openedAt),
        'closedAt': _dt(s.closedAt),
        'isOpen': s.isOpen,
        'openingFloatKurus': s.openingFloatKurus,
        'countedCashKurus': s.countedCashKurus,
        'differenceKurus': s.differenceKurus,
        'totalSalesKurus': s.totalSalesKurus,
        'cashSalesKurus': s.cashSalesKurus,
        'cardSalesKurus': s.cardSalesKurus,
        'otherSalesKurus': s.otherSalesKurus,
        'cashInKurus': s.cashInKurus,
        'cashOutKurus': s.cashOutKurus,
        'operatorName': s.operatorName,
        'note': s.note,
      };
  static CashSession sessionFromMap(Map<String, dynamic> m) => CashSession()
    ..id = m['id'] as int
    ..openedAt = _date(m['openedAt'])
    ..closedAt = _dateN(m['closedAt'])
    ..isOpen = m['isOpen'] ?? false
    ..openingFloatKurus = m['openingFloatKurus'] ?? 0
    ..countedCashKurus = m['countedCashKurus'] ?? 0
    ..differenceKurus = m['differenceKurus']
    ..totalSalesKurus = m['totalSalesKurus'] ?? 0
    ..cashSalesKurus = m['cashSalesKurus'] ?? 0
    ..cardSalesKurus = m['cardSalesKurus'] ?? 0
    ..otherSalesKurus = m['otherSalesKurus'] ?? 0
    ..cashInKurus = m['cashInKurus'] ?? 0
    ..cashOutKurus = m['cashOutKurus'] ?? 0
    ..operatorName = m['operatorName']
    ..note = m['note'] ?? '';

  // CashMovement
  static Map<String, dynamic> cashMoveToMap(CashMovement c) => {
        'id': c.id,
        'sessionId': c.sessionId,
        'type': c.type.name,
        'amountKurus': c.amountKurus,
        'reason': c.reason,
        'note': c.note,
        'refOrderId': c.refOrderId,
        'createdAt': _dt(c.createdAt),
      };
  static CashMovement cashMoveFromMap(Map<String, dynamic> m) => CashMovement()
    ..id = m['id'] as int
    ..sessionId = m['sessionId'] ?? 0
    ..type = _enum(CashMovementType.values, m['type'], CashMovementType.sale)
    ..amountKurus = m['amountKurus'] ?? 0
    ..reason = m['reason'] ?? ''
    ..note = m['note'] ?? ''
    ..refOrderId = m['refOrderId']
    ..createdAt = _date(m['createdAt']);

  // AccountingEntry
  static Map<String, dynamic> acctToMap(AccountingEntry a) => {
        'id': a.id,
        'kind': a.kind.name,
        'expenseCategory': a.expenseCategory?.name,
        'incomeCategory': a.incomeCategory?.name,
        'amountKurus': a.amountKurus,
        'title': a.title,
        'note': a.note,
        'date': _dt(a.date),
        'refOrderId': a.refOrderId,
        'isDeleted': a.isDeleted,
        'createdAt': _dt(a.createdAt),
      };
  static AccountingEntry acctFromMap(Map<String, dynamic> m) => AccountingEntry()
    ..id = m['id'] as int
    ..kind = _enum(AccountingKind.values, m['kind'], AccountingKind.expense)
    ..expenseCategory = _enumN(ExpenseCategory.values, m['expenseCategory'])
    ..incomeCategory = _enumN(IncomeCategory.values, m['incomeCategory'])
    ..amountKurus = m['amountKurus'] ?? 0
    ..title = m['title'] ?? ''
    ..note = m['note'] ?? ''
    ..date = _date(m['date'])
    ..refOrderId = m['refOrderId']
    ..isDeleted = m['isDeleted'] ?? false
    ..createdAt = _date(m['createdAt']);

  // Courier
  static Map<String, dynamic> courierToMap(delivery.Courier c) => {
        'id': c.id,
        'name': c.name,
        'phone': c.phone,
        'pairCode': c.pairCode,
        'isActive': c.isActive,
        'isDeleted': c.isDeleted,
        'totalDeliveries': c.totalDeliveries,
        'createdAt': _dt(c.createdAt),
        'updatedAt': _dt(c.updatedAt),
      };
  static delivery.Courier courierFromMap(Map<String, dynamic> m) => delivery.Courier()
    ..id = m['id'] as int
    ..name = m['name'] ?? ''
    ..phone = m['phone'] ?? ''
    ..pairCode = m['pairCode'] ?? ''
    ..isActive = m['isActive'] ?? true
    ..isDeleted = m['isDeleted'] ?? false
    ..totalDeliveries = m['totalDeliveries'] ?? 0
    ..createdAt = _date(m['createdAt'])
    ..updatedAt = _date(m['updatedAt']);

  // Delivery
  static Map<String, dynamic> deliveryToMap(delivery.Delivery d) => {
        'id': d.id,
        'orderId': d.orderId,
        'courierId': d.courierId,
        'customerName': d.customerName,
        'phone': d.phone,
        'address': d.address,
        'note': d.note,
        'totalKurus': d.totalKurus,
        'status': d.status.name,
        'createdAt': _dt(d.createdAt),
        'assignedAt': _dt(d.assignedAt),
        'onTheWayAt': _dt(d.onTheWayAt),
        'deliveredAt': _dt(d.deliveredAt),
      };
  static delivery.Delivery deliveryFromMap(Map<String, dynamic> m) => delivery.Delivery()
    ..id = m['id'] as int
    ..orderId = m['orderId'] ?? 0
    ..courierId = m['courierId']
    ..customerName = m['customerName'] ?? ''
    ..phone = m['phone'] ?? ''
    ..address = m['address'] ?? ''
    ..note = m['note'] ?? ''
    ..totalKurus = m['totalKurus'] ?? 0
    ..status = _enum(DeliveryStatus.values, m['status'], DeliveryStatus.pending)
    ..createdAt = _date(m['createdAt'])
    ..assignedAt = _dateN(m['assignedAt'])
    ..onTheWayAt = _dateN(m['onTheWayAt'])
    ..deliveredAt = _dateN(m['deliveredAt']);

  // PlatformOrderItem
  static Map<String, dynamic> platItemToMap(delivery.PlatformOrderItem i) => {
        'name': i.name,
        'qty': i.qty,
        'unitPriceKurus': i.unitPriceKurus,
        'note': i.note,
      };
  static delivery.PlatformOrderItem platItemFromMap(Map<String, dynamic> m) =>
      delivery.PlatformOrderItem()
        ..name = m['name'] ?? ''
        ..qty = (m['qty'] as num?)?.toDouble() ?? 1
        ..unitPriceKurus = m['unitPriceKurus'] ?? 0
        ..note = m['note'] ?? '';

  // PlatformOrder
  static Map<String, dynamic> platformToMap(delivery.PlatformOrder po) => {
        'id': po.id,
        'platform': po.platform.name,
        'externalCode': po.externalCode,
        'customerName': po.customerName,
        'phone': po.phone,
        'address': po.address,
        'note': po.note,
        'items': po.items.map(platItemToMap).toList(),
        'totalKurus': po.totalKurus,
        'status': po.status.name,
        'linkedOrderId': po.linkedOrderId,
        'createdAt': _dt(po.createdAt),
        'updatedAt': _dt(po.updatedAt),
      };
  static delivery.PlatformOrder platformFromMap(Map<String, dynamic> m) => delivery.PlatformOrder()
    ..id = m['id'] as int
    ..platform =
        _enum(DeliveryPlatform.values, m['platform'], DeliveryPlatform.other)
    ..externalCode = m['externalCode']
    ..customerName = m['customerName'] ?? ''
    ..phone = m['phone'] ?? ''
    ..address = m['address'] ?? ''
    ..note = m['note'] ?? ''
    ..items = ((m['items'] as List?) ?? const [])
        .map((e) => platItemFromMap((e as Map).cast<String, dynamic>()))
        .toList()
    ..totalKurus = m['totalKurus'] ?? 0
    ..status =
        _enum(PlatformOrderStatus.values, m['status'], PlatformOrderStatus.newOrder)
    ..linkedOrderId = m['linkedOrderId']
    ..createdAt = _date(m['createdAt'])
    ..updatedAt = _date(m['updatedAt']);
}