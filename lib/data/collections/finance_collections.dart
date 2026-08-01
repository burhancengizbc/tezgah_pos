import 'package:isar_community/isar.dart';
import '../enums/app_enums.dart';

part 'finance_collections.g.dart';

/// Kasa vardiyasi (Kasa Ac / Kapat / Gun Sonu).
@collection
class CashSession {
  Id id = Isar.autoIncrement;

  @Index()
  DateTime openedAt = DateTime.now();
  DateTime? closedAt;

  bool isOpen = true;

  int openingFloatKurus = 0; // acilis bakiyesi
  int countedCashKurus = 0; // kapanista sayilan nakit
  int? differenceKurus; // sayilan - beklenen

  // Vardiya ozeti (kapanista hesaplanir / canli guncellenebilir)
  int totalSalesKurus = 0; // toplam satis
  int cashSalesKurus = 0; // nakit satis
  int cardSalesKurus = 0; // kart satis
  int otherSalesKurus = 0; // diger
  int cashInKurus = 0; // elle giris
  int cashOutKurus = 0; // elle cikis

  String? operatorName; // (+) opsiyonel
  String note = '';

  /// Beklenen nakit = acilis + nakit satis + giris - cikis
  int get expectedCashKurus =>
      openingFloatKurus + cashSalesKurus + cashInKurus - cashOutKurus;
}

/// Kasa hareketi.
@collection
class CashMovement {
  Id id = Isar.autoIncrement;

  @Index()
  int sessionId = 0;

  @Enumerated(EnumType.name)
  CashMovementType type = CashMovementType.sale;

  int amountKurus = 0;
  String reason = '';
  String note = '';
  int? refOrderId;

  @Index()
  DateTime createdAt = DateTime.now();
}

/// Muhasebe kaydi (Gelir / Gider).
@collection
class AccountingEntry {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  AccountingKind kind = AccountingKind.expense;

  // kind=expense ise expenseCategory, income ise incomeCategory anlamli
  @Enumerated(EnumType.name)
  ExpenseCategory? expenseCategory;
  @Enumerated(EnumType.name)
  IncomeCategory? incomeCategory;

  int amountKurus = 0;
  String title = '';
  String note = '';

  @Index()
  DateTime date = DateTime.now();

  int? refOrderId; // satis kaynakli gelir otomatik kaydi

  @Index()
  bool isDeleted = false;

  DateTime createdAt = DateTime.now();
}
