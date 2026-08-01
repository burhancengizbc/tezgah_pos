import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Urun gorseli servisi (+ kullanici istege bagli urune resim ekleyebilir).
/// Secilen resim cihaz ici klasore KOPYALANIR (offline; internete gitmez).
/// Urunde sadece dosya yolu (imagePath) saklanir.
class ImageService {
  static const _subDir = 'images/products';

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _subDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Galeriden/dosyadan resim sec ve uygulama klasorune kaydet.
  /// Iptal edilirse null doner.
  Future<String?> pickProductImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return _persist(File(path));
  }

  /// Verilen dosyayi benzersiz isimle kalici klasore kopyalar.
  Future<String> _persist(File src) async {
    final dir = await _dir();
    final ext = p.extension(src.path).isEmpty ? '.jpg' : p.extension(src.path);
    final name =
        'p_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}$ext';
    final dest = p.join(dir.path, name);
    await src.copy(dest);
    return dest;
  }

  /// Eski gorseli sil (urun guncellenince / silinince).
  Future<void> deleteImage(String? path) async {
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {/* yok say */}
    }
  }

  /// Gorsel hala diskte var mi?
  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }
}
