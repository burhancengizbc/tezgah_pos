import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../core/utils/ascii_tr.dart';
import '../../core/utils/money.dart';
import '../models/receipt_data.dart';

/// ESC/POS termal fis bytlarini uretir. Metinler AsciiTr ile sadelestirilir;
/// boylece yazici kod sayfasindan bagimsiz her cihazda okunur cikar.
class EscPosService {
  static String _m(int k) => '${Money.plain(k)} TL';
  static String _t(String s) => AsciiTr.tr(s);

  Future<List<int>> build(ReceiptData d, {int paperMm = 80}) async {
    final profile = await CapabilityProfile.load();
    final size = paperMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(size, profile);
    final bytes = <int>[];

    bytes.addAll(g.text(_t(d.businessName),
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    if (d.headerNote.isNotEmpty) {
      bytes.addAll(
          g.text(_t(d.headerNote), styles: const PosStyles(align: PosAlign.center)));
    }
    if (d.address.isNotEmpty) {
      bytes.addAll(
          g.text(_t(d.address), styles: const PosStyles(align: PosAlign.center)));
    }
    if (d.phone.isNotEmpty) {
      bytes.addAll(g.text('Tel: ${_t(d.phone)}',
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (d.taxInfo.isNotEmpty) {
      bytes.addAll(
          g.text(_t(d.taxInfo), styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(g.hr());

    bytes.addAll(g.row([
      PosColumn(text: 'Fis No', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: '#${d.receiptNo}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));
    bytes.addAll(g.row([
      PosColumn(text: 'Tarih', width: 4),
      PosColumn(
          text: _dt(d.dateTime),
          width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(g.row([
      PosColumn(text: 'Tur', width: 4),
      PosColumn(
          text: _t(d.typeLabel),
          width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(g.hr());

    for (final l in d.lines) {
      bytes.addAll(g.text(_t(l.name)));
      bytes.addAll(g.row([
        PosColumn(text: '  ${_qty(l.qty)} x ${_m(l.unitPriceKurus)}', width: 8),
        PosColumn(
            text: _m(l.lineTotalKurus),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      if (l.extra.isNotEmpty) {
        bytes.addAll(g.text('  ${_t(l.extra)}',
            styles: const PosStyles(fontType: PosFontType.fontB)));
      }
    }
    bytes.addAll(g.hr());

    bytes.addAll(_kv(g, 'Ara Toplam', _m(d.subtotalKurus)));
    if (d.discountKurus > 0) {
      bytes.addAll(_kv(g, 'Indirim', '-${_m(d.discountKurus)}'));
    }
    bytes.addAll(_kv(g, 'KDV (dahil)', _m(d.vatKurus)));
    bytes.addAll(g.row([
      PosColumn(
          text: 'TOPLAM',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: _m(d.totalKurus),
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]));
    bytes.addAll(g.hr());

    for (final p in d.payments) {
      bytes.addAll(_kv(g, _t(p.methodLabel), _m(p.amountKurus)));
    }
    bytes.addAll(g.hr());

    if (d.footerNote.isNotEmpty) {
      bytes.addAll(g.text(_t(d.footerNote),
          styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(g.feed(1));
    bytes.addAll(
        g.text('Tezgah POS', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  List<int> _kv(Generator g, String l, String r) => g.row([
        PosColumn(text: l, width: 6),
        PosColumn(
            text: r, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  static String _dt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
