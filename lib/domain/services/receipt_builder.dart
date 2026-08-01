import 'package:isar_community/isar.dart';

import '../../data/collections/catalog_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../repositories/settings_repository.dart';
import '../models/receipt_data.dart';

const _paymentLabels = <PaymentMethod, String>{
  PaymentMethod.cash: 'Nakit',
  PaymentMethod.card: 'Kart',
  PaymentMethod.meal: 'Yemek Karti',
  PaymentMethod.other: 'Diger',
};

/// Bir siparisi yazdirilabilir ReceiptData'ya donusturur.
class ReceiptBuilder {
  final Isar isar;
  final SettingsRepository settings;
  ReceiptBuilder(this.isar, this.settings);

  Future<ReceiptData?> forOrder(int orderId) async {
    final order = await isar.collection<Order>().get(orderId);
    if (order == null) return null;

    final lines = await isar
        .collection<OrderLine>()
        .filter()
        .orderIdEqualTo(orderId)
        .sortByCreatedAt()
        .findAll();
        
    if (lines.isEmpty) return null; // İçi boş/hatalı siparişin fişini üretme
    
    final payments = await isar
        .collection<Payment>()
        .filter()
        .orderIdEqualTo(orderId)
        .findAll();

    final profile = await settings.getProfile();
    final appSettings = await settings.getSettings();

    String typeLabel;
    if (order.tableId != null) {
      final t = await isar.collection<DiningTable>().get(order.tableId!);
      typeLabel = t?.name ?? 'Masa';
    } else {
      typeLabel = order.type == OrderType.package ? 'Paket / Gel-Al' : 'Satis';
    }

    final receiptLines = <ReceiptLine>[
      for (final l in lines)
        if (!l.isVoid)
          ReceiptLine(
            name: l.productName,
            qty: l.qty,
            unitPriceKurus: l.unitPriceKurus,
            lineTotalKurus: l.lineTotalKurus,
            extra: _extraText(l),
          ),
    ];

    final taxInfo = [
      if (profile.taxOffice.isNotEmpty) 'VD: ${profile.taxOffice}',
      if (profile.taxNumber.isNotEmpty) 'VKN: ${profile.taxNumber}',
    ].join('  ');

    final footer = appSettings.receiptFooter.trim().isNotEmpty
        ? appSettings.receiptFooter.trim()
        : profile.receiptFooter;

    return ReceiptData(
      businessName: profile.name.isEmpty ? 'Isletme' : profile.name,
      address: profile.address,
      phone: profile.phone,
      taxInfo: taxInfo,
      headerNote: appSettings.receiptHeader.trim(),
      footerNote: footer,
      receiptNo: order.receiptNo.toString(), // DÜZELTİLDİ (.toString() eklendi)
      dateTime: order.closedAt ?? order.updatedAt,
      typeLabel: typeLabel,
      operatorName: order.operatorName,
      lines: receiptLines,
      subtotalKurus: order.subtotalKurus,
      discountKurus: order.discountAmountKurus,
      totalKurus: order.totalKurus,
      vatKurus: order.vatTotalKurus,
      payments: [
        for (final p in payments)
          ReceiptPayment(_paymentLabels[p.method] ?? 'Diger', p.amountKurus),
      ],
    );
  }

  String _extraText(OrderLine l) {
    final parts = <String>[
      for (final m in l.modifiers) m.optionName,
      if (l.note.trim().isNotEmpty) 'Not: ${l.note.trim()}',
    ];
    return parts.join(', ');
  }

  /// Siparişi departmanlara (Fırın, Bar, Izgara) göre parçalayıp ayrı fişler üretir.
  Future<List<({Department? department, ReceiptData receipt})>> buildForKitchen(int orderId) async {
    final order = await isar.collection<Order>().get(orderId);
    if (order == null) return [];

    final lines = await isar.collection<OrderLine>()
        .filter()
        .orderIdEqualTo(orderId)
        .sortByCreatedAt()
        .findAll();

    final activeLines = lines.where((l) => !l.isVoid).toList();
    if (activeLines.isEmpty) return [];

    final categories = await isar.collection<Category>().where().findAll();
    final departments = await isar.collection<Department>().where().findAll();

    // Satırları departman ID'sine göre grupla
    final Map<int?, List<OrderLine>> grouped = {};
    for (final l in activeLines) {
      final cat = categories.where((c) => c.id == l.categoryId).firstOrNull;
      final depId = cat?.departmentId;
      grouped.putIfAbsent(depId, () => []).add(l);
    }

    String typeLabel = order.type == OrderType.package ? 'Paket / Gel-Al' : 'Satış';
    if (order.tableId != null) {
      final t = await isar.collection<DiningTable>().get(order.tableId!);
      if (t != null) typeLabel = t.name;
    }

    final results = <({Department? department, ReceiptData receipt})>[];

    for (final entry in grouped.entries) {
      final depId = entry.key;
      final depLines = entry.value;

      final dep = departments.where((d) => d.id == depId).firstOrNull;
      
      final receipt = ReceiptData(
        businessName: '',
        address: '',
        phone: '',
        taxInfo: '',
        headerNote: dep != null ? 'DEPARTMAN: ${dep.name.toUpperCase()}' : 'ANA MUTFAK',
        footerNote: 'Sipariş No: #${order.receiptNo}',
        receiptNo: order.receiptNo.toString(), // DÜZELTİLDİ (.toString() eklendi)
        dateTime: DateTime.now(),
        typeLabel: typeLabel,
        operatorName: order.operatorName,
        // Mutfak fişinde fiyata gerek yoktur, sadece ürün ve notlar basılır
        lines: depLines.map((l) => ReceiptLine(
          name: l.productName,
          qty: l.qty,
          unitPriceKurus: 0, 
          lineTotalKurus: 0,
          extra: _extraText(l),
        )).toList(),
        subtotalKurus: 0,
        discountKurus: 0,
        totalKurus: 0,
        vatKurus: 0,
        payments: const [],
      );
      
      results.add((department: dep, receipt: receipt));
    }

    return results;
  }
}