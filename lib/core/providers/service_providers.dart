import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/image_service.dart';
import '../services/security_service.dart';
import '../services/thermal_printer_service.dart';
import '../../domain/services/checkout_service.dart';
import '../../domain/services/backup_service.dart';
import '../../domain/services/escpos_service.dart';
import '../../domain/services/platform_order_service.dart';
import '../../domain/services/receipt_builder.dart';
import '../../domain/services/receipt_pdf_service.dart';
import '../../domain/services/receipt_counter_service.dart';
import '../../domain/services/report_pdf_service.dart';
import '../../domain/services/report_service.dart';
import 'core_providers.dart';
import 'repository_providers.dart';

// auditServiceProvider repository_providers.dart icinde tanimli (paylasimli).

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

final securityServiceProvider = Provider<SecurityService>(
  (ref) => SecurityService(ref.watch(settingsRepositoryProvider)),
);

final receiptCounterServiceProvider = Provider<ReceiptCounterService>(
  (ref) => ReceiptCounterService(ref.watch(isarProvider)),
);

final checkoutServiceProvider = Provider<CheckoutService>(
  (ref) => CheckoutService(
    ref.watch(isarProvider),
    ref.watch(auditServiceProvider),
  ),
);

final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(
    ref.watch(isarProvider),
    ref.watch(accountingRepositoryProvider),
  ),
);

final reportPdfServiceProvider =
    Provider<ReportPdfService>((ref) => ReportPdfService());

// --- Fis / Yazdirma ---
final receiptBuilderProvider = Provider<ReceiptBuilder>(
  (ref) => ReceiptBuilder(
    ref.watch(isarProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final receiptPdfServiceProvider =
    Provider<ReceiptPdfService>((ref) => ReceiptPdfService());

final escPosServiceProvider =
    Provider<EscPosService>((ref) => EscPosService());

final thermalPrinterServiceProvider =
    Provider<ThermalPrinterService>((ref) => ThermalPrinterService());

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService(ref.watch(isarProvider)));

final platformOrderServiceProvider = Provider<PlatformOrderService>(
  (ref) => PlatformOrderService(
    ref.watch(platformOrderRepositoryProvider),
    ref.watch(orderRepositoryProvider),
    ref.watch(checkoutServiceProvider),
    ref.watch(isarProvider), // Doğrudan isar veritabanı örneği
    ref.watch(settingsRepositoryProvider),
  ),
);
