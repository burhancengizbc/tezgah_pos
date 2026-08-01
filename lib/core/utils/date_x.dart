import 'package:intl/intl.dart';

/// Rapor tarih araliklari ve bicimlendirme yardimcilari.
class DateX {
  DateX._();

  static final DateFormat dmy = DateFormat('dd.MM.yyyy', 'tr_TR');
  static final DateFormat dmyHm = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
  static final DateFormat hm = DateFormat('HH:mm', 'tr_TR');

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static DateTime startOfWeek(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return startOfDay(monday);
  }

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime endOfMonth(DateTime d) =>
      endOfDay(DateTime(d.year, d.month + 1, 0));

  static DateTime startOfYear(DateTime d) => DateTime(d.year, 1, 1);
  static DateTime endOfYear(DateTime d) => endOfDay(DateTime(d.year, 12, 31));
}

/// (year, seq) bazli tarih araligi yardimci tipi.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  factory DateRange.today() {
    final now = DateTime.now();
    return DateRange(DateX.startOfDay(now), DateX.endOfDay(now));
  }
  factory DateRange.thisWeek() {
    final now = DateTime.now();
    return DateRange(DateX.startOfWeek(now), DateX.endOfDay(now));
  }
  factory DateRange.thisMonth() {
    final now = DateTime.now();
    return DateRange(DateX.startOfMonth(now), DateX.endOfMonth(now));
  }
  factory DateRange.thisYear() {
    final now = DateTime.now();
    return DateRange(DateX.startOfYear(now), DateX.endOfYear(now));
  }
}
