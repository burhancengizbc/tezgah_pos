import 'package:isar_community/isar.dart';

import '../../core/utils/id_generator.dart';
import '../../data/collections/business_collections.dart';

/// Fis numarasi uretici. Yil basina tekil, tekrarlanmayan sira uretir.
/// Ornek: 2026000001, 2026000002 ...
class ReceiptCounterService {
  final Isar isar;
  ReceiptCounterService(this.isar);

  Future<int> next() async {
    final year = DateTime.now().year;
    late int receiptNo;
    await isar.writeTxn(() async {
      final col = isar.collection<ReceiptCounter>();
      var counter =
          await col.filter().yearEqualTo(year).findFirst();
      counter ??= (ReceiptCounter()..year = year..lastSeq = 0);
      counter.lastSeq += 1;
      await col.put(counter);
      receiptNo = ReceiptNoFormatter.build(year, counter.lastSeq);
    });
    return receiptNo;
  }
}
