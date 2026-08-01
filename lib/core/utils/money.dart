import 'package:intl/intl.dart';

/// Tum parasal degerler tam sayi "kurus" olarak saklanir.
/// 12.50 TL -> 1250 kurus. Boylece floating-point yuvarlama hatasi olmaz.
class Money {
  Money._();

  static final NumberFormat _fmt =
      NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 2);

  static final NumberFormat _plain =
      NumberFormat('#,##0.00', 'tr_TR');

  /// 1250 -> "₺12,50"
  static String format(int kurus) => _fmt.format(kurus / 100.0);

  /// 1250 -> "12,50" (sembolsuz)
  static String plain(int kurus) => _plain.format(kurus / 100.0);

  /// "12,50" / "12.50" / "12" -> 1250
  static int parse(String text) {
    final cleaned = text
        .replaceAll('\u20BA', '')
        .replaceAll(RegExp(r'[^0-9.,-]'), '')
        .replaceAll('.', '') // binlik ayraci
        .replaceAll(',', '.')
        .trim();
    final value = double.tryParse(cleaned) ?? 0;
    return (value * 100).round();
  }

  static int fromDouble(double tl) => (tl * 100).round();
  static double toDouble(int kurus) => kurus / 100.0;

  /// Yuzde indirim: 10000 kurus, %15 -> 1500 kurus
  static int percentOf(int kurus, double percent) =>
      (kurus * percent / 100).round();
}
