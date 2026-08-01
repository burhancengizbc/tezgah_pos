import 'package:isar_community/isar.dart';

import '../../data/collections/business_collections.dart';
import '../../data/enums/app_enums.dart';

/// Veri butunlugu izi. Onemli islemleri AuditLog'a yazar.
class AuditService {
  final Isar isar;
  AuditService(this.isar);

  Future<void> log(
    AuditAction action,
    String entity,
    int? entityId,
    String detail,
  ) async {
    final entry = AuditLog()
      ..action = action
      ..entity = entity
      ..entityId = entityId
      ..detail = detail;
    // Not: cagiranlar audit.log'u kendi writeTxn'lari BITTIKTEN sonra cagirir.
    await isar.writeTxn(() => isar.collection<AuditLog>().put(entry));
  }

  Future<List<AuditLog>> recent({int limit = 200}) {
    return isar
        .collection<AuditLog>()
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }
}
