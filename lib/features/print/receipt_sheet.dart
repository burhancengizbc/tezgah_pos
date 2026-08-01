import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';
import '../../domain/models/receipt_data.dart';

/// Bir siparis icin fis cikti secenekleri (termal + PDF).
class ReceiptSheet extends ConsumerStatefulWidget {
  final int orderId;
  final bool autoPrint; // odeme sonrasi + ayar acik + yazici varsa otomatik bas
  const ReceiptSheet({super.key, required this.orderId, this.autoPrint = false});

  static Future<void> show(BuildContext context, int orderId,
      {bool autoPrint = false}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ReceiptSheet(orderId: orderId, autoPrint: autoPrint),
    );
  }

  @override
  ConsumerState<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<ReceiptSheet> {
  ReceiptData? _data;
  AppSettings? _settings;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data =
        await ref.read(receiptBuilderProvider).forOrder(widget.orderId);
    final settings = await ref.read(settingsRepositoryProvider).getSettings();
    if (mounted) {
      setState(() {
        _data = data;
        _settings = settings;
        _loading = false;
      });
      // Odeme sonrasi otomatik bas (ayar acik + yazici secili + destekli ise)
      if (widget.autoPrint &&
          data != null &&
          settings.printAfterPayment &&
          (settings.printerMac ?? '').isNotEmpty &&
          ref.read(thermalPrinterServiceProvider).isSupported) {
        _printThermal();
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printThermal() => _run(() async {
        final d = _data!, s = _settings!;
        final bytes =
            await ref.read(escPosServiceProvider).build(d, paperMm: s.paperSizeMm);
        final res = await ref.read(thermalPrinterServiceProvider).printBytes(
              mac: s.printerMac!,
              bytes: bytes,
            );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(res.message)));
          if (res.ok) Navigator.pop(context);
        }
      });

  Future<void> _previewPdf({required bool a4}) => _run(() async {
        final d = _data!, s = _settings!;
        final bytes = await ref.read(receiptPdfServiceProvider).build(
              data: d,
              a4: a4,
              paperMm: s.paperSizeMm,
            );
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      });

  Future<void> _sharePdf() => _run(() async {
        final d = _data!, s = _settings!;
        final bytes = await ref.read(receiptPdfServiceProvider).build(
              data: d,
              paperMm: s.paperSizeMm,
            );
        await Printing.sharePdf(
            bytes: bytes, filename: 'fis_${d.receiptNo}.pdf');
      });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            : _data == null
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text('Fis verisi bulunamadi.'),
                  )
                : _content(),
      ),
    );
  }

  Widget _content() {
    final hasPrinter = (_settings?.printerMac ?? '').isNotEmpty;
    final thermalSupported =
        ref.read(thermalPrinterServiceProvider).isSupported;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.amber),
            const SizedBox(width: AppSpacing.sm),
            Text('Fis  #${_data!.receiptNo}',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (_busy)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (thermalSupported)
          FilledButton.icon(
            onPressed: _busy
                ? null
                : (hasPrinter
                    ? _printThermal
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Once Ayarlar > Yazici menusunden yazici secin.')),
                        )),
            icon: const Icon(Icons.print_rounded),
            label: Text(hasPrinter
                ? 'Termal Yaziciya Bas (${_settings?.printerName ?? "yazici"})'
                : 'Termal Yazici Secili Degil'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _previewPdf(a4: false),
          icon: const Icon(Icons.preview_rounded),
          label: const Text('Fis Onizle / Yazdir (PDF)'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _sharePdf,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Paylas'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _previewPdf(a4: true),
                icon: const Icon(Icons.description_rounded),
                label: const Text('A4 PDF'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
