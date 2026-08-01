import 'package:isar_community/isar.dart';
import '../enums/app_enums.dart';

part 'inventory_collections.g.dart';

/// Stok hareketi (stok gecmisi). Her giris/cikis burada loglanir.
@collection
class StockMovement {
  Id id = Isar.autoIncrement;

  @Index()
  int productId = 0;

  @Enumerated(EnumType.name)
  StockMovementType type = StockMovementType.adjust;

  double qty = 0; // +/- degil; type yonu belirler
  double balanceAfter = 0; // hareket sonrasi kalan stok

  String note = '';
  int? refOrderId; // satis kaynakli ise siparis id

  @Index()
  DateTime createdAt = DateTime.now();
}
