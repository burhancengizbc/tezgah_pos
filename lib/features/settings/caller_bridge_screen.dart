import 'package:flutter/material.dart';
import '../../core/services/caller_id_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class CallerBridgeScreen extends StatefulWidget {
  const CallerBridgeScreen({super.key});

  @override
  State<CallerBridgeScreen> createState() => _CallerBridgeScreenState();
}

class _CallerBridgeScreenState extends State<CallerBridgeScreen> {
  final _service = CallerIdService();
  bool _hasPermission = false;
  String? _windowsIp;
  String _lastCalledNumber = '-';

  @override
  void initState() {
    super.initState();
    _initBridge();
  }

  Future<void> _initBridge() async {
    if (!_service.isSupported) return;

    final granted = await _service.requestPermission();
    if (mounted) setState(() => _hasPermission = granted);

    if (granted) {
      // 1. Android'de otomatik Windows POS IP'sini aramaya başla
      await _service.startAutoDiscovery(onFound: (ip) {
        if (mounted) {
          setState(() => _windowsIp = ip);
        }
      });

      // 2. Telefon çağrılarını dinlemeye başla
      await _service.start((number) {
        if (mounted) setState(() => _lastCalledNumber = number);
        
        // Eğer Windows IP'si bulunmuşsa numarayı oraya fırlat
        if (_windowsIp != null) {
          CallerIdService.sendToWindows(number, _windowsIp!);
        }
      });
    }
  }

  @override
  void dispose() {
    _service.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caller ID Köprüsü')),
        body: const Center(child: Text('Bu özellik sadece Android cihazlarda çalışır.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Arayan Numara Köprüsü')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(
              title: '1. Telefon İzinleri',
              subtitle: _hasPermission ? 'Erişim Verildi' : 'Erişim Bekleniyor',
              isActive: _hasPermission,
              icon: Icons.security_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildStatusCard(
              title: '2. Kasa Bağlantısı (Windows)',
              subtitle: _windowsIp != null 
                  ? 'Kasa Bulundu: $_windowsIp' 
                  : 'Aynı WiFi ağında kasa aranıyor...',
              isActive: _windowsIp != null,
              icon: Icons.computer_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Son Çağrı Göstergesi
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
                border: Border.all(
                  color: _windowsIp != null ? Colors.green.withValues(alpha: 0.3) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.phone_in_talk_rounded, size: 48, color: AppColors.amber),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Son Aktarılan Numara', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _lastCalledNumber,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (_windowsIp != null)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Sistem aktif. Uygulamayı arka plana alabilirsiniz. '
                  'Telefon çaldığında numaralar otomatik olarak Windows kasaya aktarılacaktır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required bool isActive,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? Colors.green : AppColors.danger, size: 32),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: isActive ? Colors.green : AppColors.danger)),
              ],
            ),
          ),
          if (isActive) const Icon(Icons.check_circle_rounded, color: Colors.green)
          else const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}