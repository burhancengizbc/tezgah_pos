import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../domain/models/receipt_data.dart';

/// ReceiptData modelini, termal yazıcının anlayacağı ESC/POS bayt dizisine çevirir.
class ReceiptFormatter {
  
  /// Verilen fiş verisini 80mm (varsayılan) formatta baytlara dönüştürür.
  static Future<List<int>> format(ReceiptData data, {PaperSize paperSize = PaperSize.mm80}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Türkçe karakter (CP857) uyumluluğu için
    bytes += generator.setGlobalCodeTable('CP857');

    // 1. İŞLETME BİLGİLERİ (BAŞLIK)
    bytes += generator.text(
      _tr(data.businessName),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    
    if (data.address.isNotEmpty) {
      bytes += generator.text(_tr(data.address), styles: const PosStyles(align: PosAlign.center));
    }
    if (data.phone.isNotEmpty) {
      bytes += generator.text('Tel: ${data.phone}', styles: const PosStyles(align: PosAlign.center));
    }
    if (data.taxInfo.isNotEmpty) {
      bytes += generator.text(_tr(data.taxInfo), styles: const PosStyles(align: PosAlign.center));
    }
    
    bytes += generator.emptyLines(1);

    // 2. FİŞ DETAYLARI
    bytes += generator.row([
      PosColumn(text: 'Tarih: ${_formatDate(data.dateTime)}', width: 6),
      PosColumn(text: 'Fis No: ${data.receiptNo}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Tip: ${_tr(data.typeLabel)}', width: 6),
      PosColumn(text: 'Kasiyer: ${_tr(data.operatorName ?? '')}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr(); // Çizgi

    // 3. ÜRÜN SATIRLARI
    for (final line in data.lines) {
      bytes += generator.row([
        // Miktar ve Ürün Adı (Sola dayalı)
        PosColumn(
          text: '${line.qty % 1 == 0 ? line.qty.toInt() : line.qty}x ${_tr(line.name)}',
          width: 8,
          styles: const PosStyles(bold: true),
        ),
        // Satır Toplamı (Sağa dayalı)
        PosColumn(
          text: _formatMoney(line.lineTotalKurus),
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      
      // Ekstra/Not varsa ürünün altına küçük yazdır
      if (line.extra.isNotEmpty) {
        bytes += generator.text(
          '  ${_tr(line.extra)}',
          styles: const PosStyles(align: PosAlign.left),
        );
      }
    }

    bytes += generator.hr(); // Çizgi

    // 4. TOPLAMLAR BÖLÜMÜ
    if (data.discountKurus > 0) {
      bytes += generator.row([
        PosColumn(text: 'Ara Toplam', width: 6),
        PosColumn(text: _formatMoney(data.subtotalKurus), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Indirim', width: 6),
        PosColumn(text: '-${_formatMoney(data.discountKurus)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.emptyLines(1);
    }

    bytes += generator.row([
      PosColumn(
        text: 'GENEL TOPLAM',
        width: 6,
        styles: const PosStyles(bold: true, width: PosTextSize.size2, height: PosTextSize.size2),
      ),
      PosColumn(
        text: _formatMoney(data.totalKurus),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, width: PosTextSize.size2, height: PosTextSize.size2),
      ),
    ]);

    bytes += generator.emptyLines(1);

    // 5. ÖDEMELER
    for (final p in data.payments) {
      bytes += generator.row([
        PosColumn(text: 'Odenen (${_tr(p.methodLabel)})', width: 6),
        PosColumn(text: _formatMoney(p.amountKurus), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    // 6. ALT BİLGİ (FOOTER)
    if (data.footerNote.isNotEmpty) {
      bytes += generator.text(_tr(data.footerNote), styles: const PosStyles(align: PosAlign.center));
    }

    // Fişi bitir, biraz boşluk bırak ve kağıdı kes
    bytes += generator.emptyLines(2);
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  // Yardımcı Metodlar
  static String _formatMoney(int kurus) {
    return '${(kurus / 100).toStringAsFixed(2)} TL';
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mn = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$mn';
  }

  /// Termal yazıcılarda desteklenmeyen özel Türkçe karakterleri düzeltir
  static String _tr(String text) {
    return text
        .replaceAll('ğ', 'g').replaceAll('Ğ', 'G')
        .replaceAll('ş', 's').replaceAll('Ş', 'S')
        .replaceAll('ı', 'i').replaceAll('İ', 'I')
        .replaceAll('ç', 'c').replaceAll('Ç', 'C')
        .replaceAll('ö', 'o').replaceAll('Ö', 'O')
        .replaceAll('ü', 'u').replaceAll('Ü', 'U');
  }
}