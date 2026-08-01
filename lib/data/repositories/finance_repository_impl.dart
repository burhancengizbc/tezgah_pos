import 'package:isar_community/isar.dart';

import '../../data/collections/finance_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../core/services/audit_service.dart';

class CashRepositoryImpl implements CashRepository {
  final Isar isar;
  final AuditService audit;
  CashRepositoryImpl(this.isar, this.audit);

  IsarCollection<CashSession> get _s => isar.collection<CashSession>();
  IsarCollection<CashMovement> get _m => isar.collection<CashMovement>();

  @override
  Future<CashSession?> openSession() => currentOpen();

  @override
  Future<CashSession?> currentOpen() =>
      _s.filter().isOpenEqualTo(true).sortByOpenedAtDesc().findFirst();

  @override
  Future<CashSession> openCash(int openingFloatKurus,
      {String? operatorName}) async {
    final existing = await currentOpen();
    if (existing != null) return existing; // zaten acik
    final session = CashSession()
      ..openedAt = DateTime.now()
      ..isOpen = true
      ..openingFloatKurus = openingFloatKurus
      ..operatorName = operatorName;
    await isar.writeTxn(() async {
      await _s.put(session);
      final mv = CashMovement()
        ..sessionId = session.id
        ..type = CashMovementType.open
        ..amountKurus = openingFloatKurus
        ..reason = 'Kasa acilis';
      await _m.put(mv);
    });
    await audit.log(AuditAction.openCash, 'CashSession', session.id, '');
    return session;
  }

  @override
  Future<CashSession> closeCash(int sessionId, int countedCashKurus) async {
    late CashSession session;
    await isar.writeTxn(() async {
      final s = await _s.get(sessionId);
      if (s == null) return;
      s.isOpen = false;
      s.closedAt = DateTime.now();
      s.countedCashKurus = countedCashKurus;
      s.differenceKurus = countedCashKurus - s.expectedCashKurus;
      await _s.put(s);
      final mv = CashMovement()
        ..sessionId = sessionId
        ..type = CashMovementType.close
        ..amountKurus = countedCashKurus
        ..reason = 'Kasa kapanis (gun sonu)';
      await _m.put(mv);
      session = s;
    });
    await audit.log(AuditAction.closeCash, 'CashSession', sessionId,
        'Fark: ${session.differenceKurus}');
    return session;
  }

  @override
  Future<void> addMovement({
    required int sessionId,
    required CashMovementType type,
    required int amountKurus,
    String reason = '',
    String note = '',
    int? refOrderId,
  }) async {
    await isar.writeTxn(() async {
      final s = await _s.get(sessionId);
      if (s == null) return;
      switch (type) {
        case CashMovementType.cashIn:
          s.cashInKurus += amountKurus;
        case CashMovementType.cashOut:
          s.cashOutKurus += amountKurus;
        default:
          break;
      }
      await _s.put(s);
      final mv = CashMovement()
        ..sessionId = sessionId
        ..type = type
        ..amountKurus = amountKurus
        ..reason = reason
        ..note = note
        ..refOrderId = refOrderId;
      await _m.put(mv);
    });
  }

  @override
  Future<List<CashMovement>> movements(int sessionId) {
    return _m
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByCreatedAt()
        .findAll();
  }

  @override
  Future<List<CashSession>> history({int limit = 50}) {
    return _s.where().sortByOpenedAtDesc().limit(limit).findAll();
  }
}

class AccountingRepositoryImpl implements AccountingRepository {
  final Isar isar;
  AccountingRepositoryImpl(this.isar);

  IsarCollection<AccountingEntry> get _e => isar.collection<AccountingEntry>();

  @override
  Future<int> addEntry(AccountingEntry entry) async {
    late int id;
    await isar.writeTxn(() async {
      id = await _e.put(entry);
    });
    return id;
  }

  @override
  Future<void> softDelete(int id) async {
    await isar.writeTxn(() async {
      final e = await _e.get(id);
      if (e != null) {
        e.isDeleted = true;
        await _e.put(e);
      }
    });
  }

  @override
  Future<List<AccountingEntry>> inRange(DateTime start, DateTime end,
      {AccountingKind? kind}) {
    var q = _e
        .filter()
        .isDeletedEqualTo(false)
        .dateBetween(start, end);
    if (kind != null) q = q.kindEqualTo(kind);
    return q.sortByDateDesc().findAll();
  }

  @override
  Future<int> totalKurus(
      DateTime start, DateTime end, AccountingKind kind) async {
    final rows = await inRange(start, end, kind: kind);
    return rows.fold<int>(0, (sum, e) => sum + e.amountKurus);
  }
}
