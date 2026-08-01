import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/ascii_tr.dart';
import '../../core/utils/money.dart';
import '../models/receipt_data.dart';

/// Fis PDF'i: termal rulo (58/80mm) veya A4. Tamamen offline.
/// Metinler AsciiTr ile sadelestirilir (gomulu fontlarda Turkce/₺ render sorunu olmaz).
class ReceiptPdfService {
  static String _m(int kurus) => '${Money.plain(kurus)} TL';
  static String _t(String s) => AsciiTr.tr(s);

  Future<Uint8List> build({
    required ReceiptData data,
    bool a4 = false,
    int paperMm = 80,
  }) async {
    final doc = pw.Document();

    if (a4) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Align(
          alignment: pw.Alignment.topCenter,
          child: pw.Container(
            width: 300,
            child: _body(data, baseFont: 10),
          ),
        ),
      ));
    } else {
      final widthPt = paperMm * PdfPageFormat.mm;
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(widthPt, double.infinity,
            marginAll: 5 * PdfPageFormat.mm),
        build: (_) => _body(data, baseFont: paperMm <= 58 ? 7.5 : 8.5),
      ));
    }
    return doc.save();
  }

  pw.Widget _body(ReceiptData d, {required double baseFont}) {
    final small = pw.TextStyle(fontSize: baseFont - 1.5);
    final normal = pw.TextStyle(fontSize: baseFont);
    final bold =
        pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold);
    final big = pw.TextStyle(
        fontSize: baseFont + 3.5, fontWeight: pw.FontWeight.bold);

    pw.Widget dashed() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey600),
        );

    pw.Widget kv(String l, String r, {pw.TextStyle? st}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Text(l, style: st ?? normal)),
            pw.SizedBox(width: 6),
            pw.Text(r, style: st ?? normal),
          ],
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(child: pw.Text(_t(d.businessName), style: big)),
        if (d.headerNote.isNotEmpty)
          pw.Center(child: pw.Text(_t(d.headerNote), style: small)),
        if (d.address.isNotEmpty)
          pw.Center(
              child: pw.Text(_t(d.address),
                  style: small, textAlign: pw.TextAlign.center)),
        if (d.phone.isNotEmpty)
          pw.Center(child: pw.Text('Tel: ${_t(d.phone)}', style: small)),
        if (d.taxInfo.isNotEmpty)
          pw.Center(child: pw.Text(_t(d.taxInfo), style: small)),
        dashed(),
        kv('Fis No', '#${d.receiptNo}', st: bold),
        kv('Tarih', _dt(d.dateTime), st: small),
        kv('Tur', _t(d.typeLabel), st: small),
        if ((d.operatorName ?? '').isNotEmpty)
          kv('Personel', _t(d.operatorName!), st: small),
        dashed(),
        // Satirlar
        for (final l in d.lines) ...[
          kv('${_qty(l.qty)} x ${_m(l.unitPriceKurus)}', _m(l.lineTotalKurus),
              st: normal),
          pw.Text(_t(l.name), style: normal),
          if (l.extra.isNotEmpty)
            pw.Text('  ${_t(l.extra)}', style: small),
          pw.SizedBox(height: 2),
        ],
        dashed(),
        kv('Ara Toplam', _m(d.subtotalKurus), st: normal),
        if (d.discountKurus > 0)
          kv('Indirim', '-${_m(d.discountKurus)}', st: normal),
        kv('KDV (dahil)', _m(d.vatKurus), st: small),
        pw.SizedBox(height: 2),
        kv('TOPLAM', _m(d.totalKurus), st: big),
        dashed(),
        for (final p in d.payments)
          kv(_t(p.methodLabel), _m(p.amountKurus), st: normal),
        dashed(),
        if (d.footerNote.isNotEmpty)
          pw.Center(
              child: pw.Text(_t(d.footerNote),
                  style: small, textAlign: pw.TextAlign.center)),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('Tezgah POS', style: small)),
      ],
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  static String _dt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
