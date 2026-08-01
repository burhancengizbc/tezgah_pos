/// Fis numarasi formati: YYYY + 6 haneli sira.
/// Ornek: 2026 + 000001 -> 2026000001
class ReceiptNoFormatter {
  ReceiptNoFormatter._();

  /// year=2026, seq=1 -> 2026000001
  static int build(int year, int seq) {
    return year * 1000000 + seq;
  }

  /// 2026000001 -> "2026000001"
  static String display(int receiptNo) => receiptNo.toString();
}
