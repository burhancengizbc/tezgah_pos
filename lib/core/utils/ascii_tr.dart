/// Turkce karakterleri ASCII'ye cevirir. Fis/PDF ciktilarinda gomulu standart
/// fontlar ve termal yazici kod sayfasi sorunlarini tamamen ortadan kaldirir
/// (her cihazda garantili, okunur cikti). ₺ -> "TL".
class AsciiTr {
  AsciiTr._();

  static const _map = {
    'ç': 'c', 'Ç': 'C',
    'ğ': 'g', 'Ğ': 'G',
    'ı': 'i', 'İ': 'I',
    'ö': 'o', 'Ö': 'O',
    'ş': 's', 'Ş': 'S',
    'ü': 'u', 'Ü': 'U',
    '\u20BA': 'TL', // Turk Lirasi sembolu
    '\u20AC': 'EUR',
    '\u00A0': ' ', // nbsp
  };

  static String tr(String input) {
    final sb = StringBuffer();
    for (final ch in input.split('')) {
      sb.write(_map[ch] ?? ch);
    }
    return sb.toString();
  }
}
