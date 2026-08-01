# BUILD HATALARI — COZUM REHBERI

Bildirdigin hatalarin tek tek karsiligi ve cozumu.

## 1) "Use the actions in the editor tool bar to undo / overwrite"
Bu bir KOD hatasi degil; editorun (Cursor/VSCode) dosyayi otomatik
guncelleyemedigini soyleyen IDE uyarisidir. "Overwrite / Accept" deyip devam et.

## 2) `.isDeletedEqualTo(false)` Order'da kirmizi
## 3) `orders.where((o) => o.isDeleted == false)` kirmizi
Bu iki satir BU projenin kodunda YOK. Bizim `Order` modelinde `isDeleted` alani
bulunmaz; siparisler silinmez, **iptal** edilir (`status == OrderStatus.cancelled`).
Dogru kullanim:
```dart
// teslim/iptal disindakiler
final aktif = await isar.orders.filter()
    .not().statusEqualTo(OrderStatus.cancelled)
    .findAll();
```
Eger gercekten siparislerde "soft delete" istiyorsan Order'a `@Index() bool isDeleted`
ekleyebilirim — soyle, ekleyeyim. (Su an mimaride gerek yok.)

## 4 & 5) Gradle: "Cannot run Project.afterEvaluate(Action) when already evaluated"
Bu, `android/build.gradle.kts` icine eklenmis su workaround'dan kaynaklanir:
```kotlin
subprojects {
    project.evaluationDependsOn(":app")   // <-- sorun bu satir
    afterEvaluate { ... namespace ... }
}
```
Bu blok, eski Isar'in namespace sorununu yamalamak icindi. **Artik gereksiz** (bkz. #6).
**YAP:** `android/build.gradle.kts` icindeki bu `subprojects { ... }` blogunu TAMAMEN SIL.

## 6) ASIL HATA — Isar / AGP 8 namespace
```
Incorrect package="dev.isar.isar_flutter_libs" found in source AndroidManifest.xml
Setting the namespace via the package attribute ... is no longer supported.
BUILD FAILED
```
Sebep: `isar_flutter_libs 3.1.0+1` 3 yildir guncellenmedi ve Android Gradle Plugin 8
ile uyumsuz (manifest'teki `package=` reddediliyor).

**COZUM (bu projede UYGULANDI):** bakimi suren topluluk fork'una gecildi:
- `isar` -> `isar_community: ^3.3.1`
- `isar_flutter_libs` -> `isar_community_flutter_libs: ^3.3.1`
- `isar_generator` -> `isar_community_generator: ^3.3.1`
- tum `import 'package:isar/isar.dart'` -> `import 'package:isar_community/isar.dart'`

`isar_community` "Android Namespaces support" ve Android 16KB sayfa boyutu desteklerini
icerir; namespace sorununu kaynaginda cozer. API ayni (kod degisikligi gerekmez).

## Senin yapman gerekenler (sirayla)
```bash
cd tezgah_pos
# 1) android/build.gradle.kts icindeki subprojects{...} workaround'unu sil (#4-5)
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # *.g.dart yeniden uretilir
flutter run
```
Not: `flutter create . --platforms=...` ile android/ klasorunu olusturduysan,
yukaridaki gradle workaround'u muhtemelen sen/eski rehber eklemistir; silmen yeterli.
isar_community ile namespace yamasina gerek kalmaz.
