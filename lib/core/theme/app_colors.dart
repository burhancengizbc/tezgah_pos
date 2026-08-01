import 'package:flutter/material.dart';

/// Tezgah POS kimligi: "Grafit & Kehribar".
/// Koyu tema varsayilan (mutfak/tezgah isiginda goz yormaz, parlama az).
/// Aydinlik tema temiz ve yuksek kontrastli.
class AppColors {
  AppColors._();

  // Marka
  static const Color amber = Color(0xFFFFB300); // birincil vurgu (kehribar)
  static const Color amberDeep = Color(0xFFFF8F00);
  static const Color teal = Color(0xFF26A69A); // ikincil (onay/aktif)

  // Durum renkleri
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFEF6C00);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // Masa durumu
  static const Color tableEmpty = Color(0xFF455A64);
  static const Color tableOccupied = Color(0xFFFFB300);
  static const Color tableAwaiting = Color(0xFFC62828);

  // --- KOYU TEMA (grafit) ---
  static const Color dBg = Color(0xFF15161A);
  static const Color dSurface = Color(0xFF1E2026);
  static const Color dSurface2 = Color(0xFF262931);
  static const Color dBorder = Color(0xFF31343D);
  static const Color dText = Color(0xFFECEDEF);
  static const Color dTextDim = Color(0xFF9AA0AA);

  // --- AYDINLIK TEMA ---
  static const Color lBg = Color(0xFFF4F5F7);
  static const Color lSurface = Color(0xFFFFFFFF);
  static const Color lSurface2 = Color(0xFFEDEFF3);
  static const Color lBorder = Color(0xFFDDE1E7);
  static const Color lText = Color(0xFF1A1C20);
  static const Color lTextDim = Color(0xFF5C636E);
   
   
  // Ana rengini buraya ekledik
  static const Color primary = Color(0xFF1E88E5);
}
