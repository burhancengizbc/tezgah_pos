import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/money.dart';
import '../models/report_models.dart';

/// Rapor PDF'i olusturur. Tamamen offline; gomulu standart fontlar kullanilir.
/// Not: standart PDF fontlari Turkce ozel karakterleri (s, g, i...) ve ₺
/// sembolunu tam desteklemedigi icin metinler ASCII + "TL" bicimindedir
/// (uygulamanin geneliyle ayni konvansiyon).
class ReportPdfService {
  /// kurus -> "1.234,56 TL"
  static String _tl(int kurus) => '${Money.plain(kurus)} TL';

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  Future<Uint8List> build({
    required String businessName,
    required String periodLabel,
    required DateTime generatedAt,
    required SalesSummary summary,
    required List<ProductSalesRow> topProducts,
    required List<ProductSalesRow> bottomProducts,
    required List<CategorySalesRow> categories,
    required List<ExpenseRow> expenses,
    Map<String, String> expenseLabels = const {},
  }) async {
    final doc = pw.Document();
    final genStr =
        '${generatedAt.day.toString().padLeft(2, '0')}.${generatedAt.month.toString().padLeft(2, '0')}.${generatedAt.year} '
        '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _header(businessName, periodLabel, genStr),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Tezgah POS  -  Sayfa ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          _summaryBlock(summary),
          pw.SizedBox(height: 16),
          if (topProducts.isNotEmpty) ...[
            _sectionTitle('EN COK SATAN URUNLER'),
            _productTable(topProducts),
            pw.SizedBox(height: 14),
          ],
          if (bottomProducts.isNotEmpty) ...[
            _sectionTitle('EN AZ SATAN URUNLER'),
            _productTable(bottomProducts),
            pw.SizedBox(height: 14),
          ],
          if (categories.isNotEmpty) ...[
            _sectionTitle('KATEGORI KIRILIMI'),
            _categoryTable(categories),
            pw.SizedBox(height: 14),
          ],
          if (expenses.isNotEmpty) ...[
            _sectionTitle('GIDER KIRILIMI'),
            _expenseTable(expenses, expenseLabels),
          ],
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header(String business, String period, String gen) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(business.isEmpty ? 'Isletme' : business,
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Satis / Kar-Zarar Raporu',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Donem: $period',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Olusturma: $gen',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 0.8, color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(t,
            style:
                pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _summaryBlock(SalesSummary s) {
    final avg = s.orderCount == 0 ? 0 : (s.totalSalesKurus / s.orderCount).round();
    pw.Widget cell(String label, String value, {bool strong = false, PdfColor? color}) {
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.all(3),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: strong ? 12 : 10,
                      fontWeight:
                          strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: color)),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      children: [
        pw.Row(children: [
          cell('Ciro (net)', _tl(s.totalSalesKurus), strong: true),
          cell('Urun maliyeti', _tl(s.totalCostKurus)),
          cell('Brut kar', _tl(s.grossProfitKurus),
              strong: true, color: PdfColors.green800),
        ]),
        pw.Row(children: [
          cell('Giderler', _tl(s.expensesKurus), color: PdfColors.red800),
          cell('Net kar', _tl(s.netProfitKurus),
              strong: true,
              color:
                  s.netProfitKurus >= 0 ? PdfColors.green800 : PdfColors.red800),
          cell('KDV (dahil)', _tl(s.vatTotalKurus)),
        ]),
        pw.Row(children: [
          cell('Siparis sayisi', '${s.orderCount}'),
          cell('Ortalama fis', _tl(avg)),
          cell('Toplam indirim', _tl(s.discountKurus)),
        ]),
      ],
    );
  }

  pw.Widget _productTable(List<ProductSalesRow> rows) {
    return pw.TableHelper.fromTextArray(
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle:
          pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headers: const ['Urun', 'Adet', 'Satis', 'Kar'],
      data: [
        for (final r in rows)
          [r.productName, _qty(r.qty), _tl(r.salesKurus), _tl(r.profitKurus)],
      ],
    );
  }

  pw.Widget _categoryTable(List<CategorySalesRow> rows) {
    final total = rows.fold<int>(0, (s, r) => s + r.salesKurus);
    return pw.TableHelper.fromTextArray(
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle:
          pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headers: const ['Kategori', 'Satis', 'Kar', 'Pay'],
      data: [
        for (final r in rows)
          [
            r.categoryName,
            _tl(r.salesKurus),
            _tl(r.profitKurus),
            total == 0
                ? '-'
                : '%${(r.salesKurus * 100 / total).toStringAsFixed(0)}',
          ],
      ],
    );
  }

  pw.Widget _expenseTable(List<ExpenseRow> rows, Map<String, String> labels) {
    final total = rows.fold<int>(0, (s, r) => s + r.amountKurus);
    return pw.TableHelper.fromTextArray(
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle:
          pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      headers: const ['Gider Kategorisi', 'Tutar'],
      data: [
        for (final r in rows) [labels[r.category] ?? r.category, _tl(r.amountKurus)],
        ['TOPLAM', _tl(total)],
      ],
    );
  }
}
