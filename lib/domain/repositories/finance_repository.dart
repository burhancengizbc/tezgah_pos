import '../../data/collections/finance_collections.dart';
import '../../data/enums/app_enums.dart';

abstract interface class CashRepository {
  Future<CashSession?> openSession();
  Future<CashSession?> currentOpen();
  Future<CashSession> openCash(int openingFloatKurus, {String? operatorName});
  Future<CashSession> closeCash(int sessionId, int countedCashKurus);

  Future<void> addMovement({
    required int sessionId,
    required CashMovementType type,
    required int amountKurus,
    String reason = '',
    String note = '',
    int? refOrderId,
  });

  Future<List<CashMovement>> movements(int sessionId);
  Future<List<CashSession>> history({int limit = 50});
}

abstract interface class AccountingRepository {
  Future<int> addEntry(AccountingEntry entry);
  Future<void> softDelete(int id);
  Future<List<AccountingEntry>> inRange(DateTime start, DateTime end,
      {AccountingKind? kind});
  Future<int> totalKurus(DateTime start, DateTime end, AccountingKind kind);
}
