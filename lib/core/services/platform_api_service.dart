import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http; // Şimdilik kapalı
import '../../data/collections/delivery_collections.dart';
import '../../data/enums/app_enums.dart';

/// Gerçek sunucu yapılana kadar UI testleri için kullanılan Sahte (Mock) API Servisi
class PlatformApiService {
  
  /// SUNUCUDAN GELİYORMUŞ GİBİ DAVRANACAK SAHTE JSON VERİSİ
  final String _mockJsonResponse = '''
  {
    "success": true,
    "data": [
      {
        "id": "TY-987654",
        "platform": "trendyolGo",
        "status": "newOrder",
        "customerName": "Oğuzhan A.",
        "phone": "+905415944154",
        "address": "Eski İstanbul Cd. Kent Konut 5 Sit...",
        "note": "Ruffles yoksa Doritos peynirli olabilir.",
        "totalKurus": 12530,
        "items": [
          { "name": "Kinder Chocolate 4'lü", "qty": 2.0, "unitPriceKurus": 3100, "note": "" },
          { "name": "Ruffles Originals", "qty": 1.0, "unitPriceKurus": 1650, "note": "" }
        ]
      },
      {
        "id": "YS-112233",
        "platform": "yemeksepeti",
        "status": "preparing",
        "customerName": "Emre A.",
        "phone": "+905551234567",
        "address": "Atatürk Mah. Cumhuriyet Cad. No:12 D:4",
        "note": "Zile basmayın lütfen, bebek uyuyor.",
        "totalKurus": 15600,
        "items": [
          { "name": "İşkembe Çorbası", "qty": 2.0, "unitPriceKurus": 7800, "note": "Bol sarımsaklı" }
        ]
      }
    ]
  }
  ''';

  /// Siparişleri çeker (Geçici olarak HTTP yerine yukarıdaki String'i okur)
  Future<List<PlatformOrder>> fetchActiveOrders() async {
    try {
      // Gerçek bir ağ isteği yapıyormuşuz gibi 1 saniye bekletelim
      await Future.delayed(const Duration(seconds: 1));

      // String halindeki sahte veriyi JSON'a çeviriyoruz
      final json = jsonDecode(_mockJsonResponse);
      
      if (json['success'] == true) {
        final List data = json['data'];
        return data.map((e) => _fromJsonToOrder(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Siparişleri çekerken hata: $e');
      return [];
    }
  }

  /// Sipariş durumunu günceller (Sadece simülasyon)
  Future<bool> updateOrderStatus(String externalOrderId, PlatformOrderStatus newStatus) async {
    // Gerçekte burada HTTP POST atılacak. 
    // Şimdilik işlemi başarılı kabul edip true dönüyoruz.
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('Sipariş ($externalOrderId) durumu güncellendi: \${newStatus.name}');
    return true;
  }

  /// JSON verisini yerel Isar PlatformOrder modeline dönüştüren yardımcı metod
  PlatformOrder _fromJsonToOrder(Map<String, dynamic> json) {
    final order = PlatformOrder()
      ..externalCode = json['id']
      ..platform = DeliveryPlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => DeliveryPlatform.other,
      )
      ..status = PlatformOrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PlatformOrderStatus.newOrder,
      )
      ..customerName = json['customerName'] ?? ''
      ..phone = json['phone'] ?? ''
      ..address = json['address'] ?? ''
      ..note = json['note'] ?? ''
      ..totalKurus = json['totalKurus'] ?? 0;

    if (json['items'] != null) {
      order.items = (json['items'] as List).map((i) {
        return PlatformOrderItem()
          ..name = i['name'] ?? ''
          ..qty = (i['qty'] ?? 1).toDouble()
          ..unitPriceKurus = i['unitPriceKurus'] ?? 0
          ..note = i['note'] ?? '';
      }).toList();
    }
    
    return order;
  }
}