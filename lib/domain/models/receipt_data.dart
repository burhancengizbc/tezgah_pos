/// Fis ciktisi icin hazirlanmis veri (PDF ve ESC/POS uretiminde ortak kullanilir).
/// Isar koleksiyonlarindan bagimsizdir; boylece cikti ureticileri saf kalir.
class ReceiptData {
  final String businessName;
  final String address;
  final String phone;
  final String taxInfo; // "VD: ... VKN: ..." (bos olabilir)
  final String headerNote; // ust not
  final String footerNote; // alt not

  final String receiptNo;
  final DateTime dateTime;
  final String typeLabel; // "Masa 3" / "Paket" / "Gel-Al"
  final String? operatorName;

  final List<ReceiptLine> lines;

  final int subtotalKurus;
  final int discountKurus;
  final int totalKurus;
  final int vatKurus;

  final List<ReceiptPayment> payments;

  const ReceiptData({
    required this.businessName,
    required this.address,
    required this.phone,
    required this.taxInfo,
    required this.headerNote,
    required this.footerNote,
    required this.receiptNo,
    required this.dateTime,
    required this.typeLabel,
    required this.operatorName,
    required this.lines,
    required this.subtotalKurus,
    required this.discountKurus,
    required this.totalKurus,
    required this.vatKurus,
    required this.payments,
  });
}

class ReceiptLine {
  final String name;
  final double qty;
  final int unitPriceKurus;
  final int lineTotalKurus;
  final String extra; // secenekler / not (tek satir, opsiyonel)

  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPriceKurus,
    required this.lineTotalKurus,
    this.extra = '',
  });
}

class ReceiptPayment {
  final String methodLabel;
  final int amountKurus;
  const ReceiptPayment(this.methodLabel, this.amountKurus);
}
