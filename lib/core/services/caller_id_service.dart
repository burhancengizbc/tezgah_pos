import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';

import '../../core/providers/repository_providers.dart';
import '../../data/collections/people_collections.dart';

// ============================================================================
// 1. ANDROID İÇİN ÇAĞRI YAKALAMA VE KÖPRÜ SERVİSİ
// ============================================================================

/// Gelen arama numarasini yakalar (YALNIZCA Android).
/// iOS ve masaustunde uygulama gelen numarayi okuyamaz -> guard'li (devre disi).
///
/// NOT (native kurulum): Android'de calismasi icin
/// android/app/src/main/AndroidManifest.xml dosyasina su izinler eklenmeli:
///   <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
///   <uses-permission android:name="android.permission.READ_CALL_LOG"/>
class CallerIdService {
  StreamSubscription<PhoneState>? _sub;
  RawDatagramSocket? _discoverySocket;

  bool get isSupported => Platform.isAndroid;

  /// Gerekli izinleri ister. Verildiyse true.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final statuses = await [
      Permission.phone,
    ].request();
    return statuses[Permission.phone]?.isGranted ?? false;
  }

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return Permission.phone.isGranted;
  }

  /// Dinlemeyi baslatir. Gelen arama (CALL_INCOMING) ve numara varsa
  /// [onIncoming] cagrilir. Ayni numara icin tekrar tetiklenmeyi onlemek
  /// adina son numara hatirlanir.
  Future<void> start(void Function(String number) onIncoming) async {
    if (!isSupported) return;
    await stop();
    String? lastNumber;
    _sub = PhoneState.stream.listen((event) {
      final status = event.status;
      final number = event.number;
      if (status == PhoneStateStatus.CALL_INCOMING &&
          number != null &&
          number.trim().isNotEmpty) {
        if (number == lastNumber) return;
        lastNumber = number;
        onIncoming(number.trim());
      } else if (status == PhoneStateStatus.CALL_ENDED ||
          status == PhoneStateStatus.NOTHING) {
        lastNumber = null;
      }
    });
  }

  /// Ağdaki Windows kasayı otomatik bulmak için dinlemeyi başlatır
  Future<void> startAutoDiscovery({required void Function(String ip) onFound}) async {
    if (!isSupported) return;
    try {
      // 8081 portundan ağdaki yayınları dinliyoruz
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
      _discoverySocket!.broadcastEnabled = true;
      
      debugPrint('🔍 Windows POS ağda aranıyor...');
      
      _discoverySocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            if (message == 'TEZGAH_POS_BEACON') {
              // Yayını yakaladık, cihazın IP adresini alıyoruz!
              final ip = datagram.address.address;
              debugPrint('🟢 Windows POS bulundu: $ip');
              onFound(ip);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Otomatik arama hatası: $e');
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _discoverySocket?.close();
    _discoverySocket = null;
  }

  /// Android telefondan Windows kasaya ağ üzerinden numarayı fırlatır
  static Future<void> sendToWindows(String number, String windowsIp) async {
    try {
      final client = HttpClient();
      // Bağlantı süresini kısa tutuyoruz ki telefon meşgul olmasın
      client.connectionTimeout = const Duration(seconds: 3); 
      
      // Windows kasanın IP adresine ve 8080 portuna POST isteği atıyoruz
      final request = await client.post(windowsIp, 8080, '/incoming-call');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'phone': number}));
      
      final response = await request.close();
      if (response.statusCode == 200) {
        debugPrint('✅ Çağrı Windows kasaya başarıyla iletildi: $number');
      } else {
        debugPrint('⚠️ Windows kasa çağrıyı reddetti: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Windows kasaya ulaşılamadı (IP yanlış veya aynı ağda değiller): $e');
    }
  }
}

// ============================================================================
// 2. WINDOWS / MASAÜSTÜ İÇİN ÇAĞRI KARŞILAMA SUNUCUSU (CALLER ID SERVER)
// ============================================================================

// --- Arayan Çağrı Veri Modeli ---
class IncomingCall {
  final String phone;
  final Customer? customer;
  final DateTime timestamp;

  IncomingCall({
    required this.phone,
    this.customer,
    required this.timestamp,
  });
}

// --- Ekrana Bildirim Düşürmek İçin State Provider ---
final incomingCallProvider = StateProvider<IncomingCall?>((ref) => null);

// --- Sunucu Servisini Başlatan Provider ---
final callerIdServerProvider = Provider<CallerIdServer>((ref) {
  return CallerIdServer(ref);
});

// --- Ana Sunucu Sınıfı ---
class CallerIdServer {
  final ProviderRef ref;
  HttpServer? _server;
  Timer? _broadcastTimer;
  RawDatagramSocket? _udpSocket;

  CallerIdServer(this.ref);

  Future<void> start() async {
    // Sunucuyu sadece Masaüstü (Windows/Mac/Linux) ortamlarında başlatıyoruz
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        // 1. Çağrıları dinleyeceğimiz HTTP sunucusunu başlatıyoruz
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
        debugPrint('✅ Caller ID Sunucusu Başlatıldı (Port: 8080)');

        // 2. Android cihazın bizi bulabilmesi için ağa otomatik yayın başlatıyoruz
        await _startUdpBroadcast();

        _server!.listen((HttpRequest request) async {
          // Eğer Android uygulamamızdan '/incoming-call' yoluna bir POST isteği gelirse
          if (request.uri.path == '/incoming-call' && request.method == 'POST') {
            await _handleIncomingCall(request);
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..write('Route Not Found')
              ..close();
          }
        });
      } catch (e) {
        debugPrint('❌ Caller ID Sunucu Hatası: $e');
      }
    }
  }

  Future<void> _handleIncomingCall(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      // Telefondan gelen ham numarayı alıyoruz (Örn: +905321234567)
      final phone = data['phone'] as String?;

      if (phone != null && phone.isNotEmpty) {
        debugPrint('📞 Yeni Çağrı Yakalandı: $phone');

        // 1. Veritabanında (Isar) bu numara kayıtlı mı diye hızlıca tarıyoruz
        final customerRepo = ref.read(customerRepositoryProvider);
        
        // Gelen numaraya göre veritabanında arama yapıyoruz
        final list = await customerRepo.page(search: phone, offset: 0, limit: 1);
        final customer = list.isNotEmpty ? list.first : null;

        // 2. State'i güncelliyoruz (Bu sayede UI tetiklenecek ve Pop-up açılacak)
        ref.read(incomingCallProvider.notifier).state = IncomingCall(
          phone: phone,
          customer: customer,
          timestamp: DateTime.now(),
        );

        // 3. Android telefona "Aldım ve ekrana yansıttım" cevabı veriyoruz
        request.response
          ..statusCode = HttpStatus.ok
          ..write('OK')
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Phone number is missing')
          ..close();
      }
    } catch (e) {
      debugPrint('❌ Çağrı İşleme Hatası: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Internal Error')
        ..close();
    }
  }

  Future<void> _startUdpBroadcast() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket!.broadcastEnabled = true;
      
      final beaconData = utf8.encode('TEZGAH_POS_BEACON');
      
      // Her 2 saniyede bir ağa (tüm cihazlara) kendimizi bildiriyoruz
      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _udpSocket!.send(beaconData, InternetAddress('255.255.255.255'), 8081);
      });
      debugPrint('📡 Otomatik Keşif Yayını (UDP) Başladı');
    } catch (e) {
      debugPrint('❌ UDP Yayın Hatası: $e');
    }
  }

  void stop() {
    _server?.close();
    _broadcastTimer?.cancel();
    _udpSocket?.close();
    debugPrint('🛑 Caller ID Sunucusu ve Keşif Yayını Durduruldu.');
  }
}