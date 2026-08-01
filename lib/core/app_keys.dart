import 'package:flutter/material.dart';

/// Uygulama genelinde erisilebilen anahtarlar.
/// Caller ID gibi olaylarda herhangi bir ekrandan diyalog/uyari gosterebilmek
/// icin kullanilir.
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
