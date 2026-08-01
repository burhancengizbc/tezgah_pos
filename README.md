# Tezgah POS

Offline-first yerel **adisyon & isletme yonetim sistemi**.
Flutter (Android / iOS / Windows / macOS) · Riverpod · Isar · Clean Architecture.

> Tum veriler cihaz icinde tutulur. Internet zorunlu degildir. Bulut / uyelik /
> online siparis / kurye / garson hesabi / coklu sube / sadakat / QR menu **yoktur**
> (istenmedi).

---

## Bu pakette ne var? (FAZ 1 — Temel + Veri Katmani)

- Proje iskeleti, `pubspec.yaml`, lint, klasor yapisi
- Tasarim sistemi: **Grafit & Kehribar** koyu/aydinlik tema, dokunmatik olcek
- **Tum Isar koleksiyonlari (entity modelleri):**
  Isletme Profili, Ayarlar/Guvenlik, Fis Sayaci, Audit Log, Kategori, Urun (+secenekler),
  Stok Hareketi, Musteri, Masa, Siparis, Siparis Satiri, Odeme, Kasa Vardiyasi,
  Kasa Hareketi, Muhasebe Kaydi
- Para yonetimi: tum tutarlar **kurus (int)** olarak saklanir → yuvarlama hatasi yok
- `IsarService`, Riverpod cekirdek provider'lari, calisan adaptif ana iskelet

## Kurulum

```bash
flutter create . --platforms=android,ios,windows,macos   # mevcut klasore platform iskeleti
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Isar *.g.dart uretir
flutter run
```

> Not: `*.g.dart` dosyalari `build_runner` ile uretilir; bu yuzden pakette yoktur.
> Surum uyusmazligi olursa `flutter pub upgrade` ile paketleri guncelleyin.

---

## Mimari

Pragmatik Clean Architecture (Isar'a uygun):

```
lib/
  core/        sabitler, tema, hata, util, veritabani, provider
  data/        enums, collections (Isar entity'leri)  ← FAZ 1 TAMAM
  domain/      repository arayuzleri + usecase'ler     ← FAZ 2
  features/    UI (Riverpod) modul modul               ← FAZ 3+
```

## Yol Haritasi

| Faz | Icerik | Durum |
|-----|--------|-------|
| 1 | Temel + tum entity/Isar veri katmani | ✅ |
| 2 | Repository + UseCase + servisler (fis no, stok dusumu, kar/zarar, kasa, checkout, guvenlik, gorsel) | ✅ bu paket |
| 3 | Satis/hizli siparis, masa izgarasi, gorselli urun karti, secenekler, hesap bol (UI) | ✅ |
| 4 | Kasa (ac/kapat/gun sonu Z raporu, para giris-cikis), muhasebe (gelir/gider), musteri yonetimi UI | ✅ |
| 5 | Raporlama UI (donem ozeti, kar/zarar, en cok/az satan, kategori-gider kirilimi, PDF) | ✅ bu paket |
| 6 | Yazdirma: ESC/POS termal (Bluetooth) + 58/80mm & A4 PDF fis, odeme sonrasi fis | ✅ bu paket |
| 7 | Caller ID: gelen aramada kayitli musteri eslestirme + hizli paket siparisi (Android) | ✅ bu paket |
| 8 | Yedekleme (JSON+ZIP al/geri yukle) + kurulum sihirbazi | ✅ bu paket |
| 9  | + Yerel ag (LAN) sunucusu + "Cagri" companion uygulamasi (gelen aramayi Tezgah'a aktarma) | ✅ bu paket |
| 10 | + Kurye modulu: siparisi kuryeye atama/takip + "Tezgah Kurye" companion uygulamasi | ✅ bu paket |
| 11 | + Platform siparisleri gelen kutusu (yeni/kabul/hazirla/yola cik/teslim) + yerel alim ucu | ✅ bu paket |
| 12 | Performans (indexler, sonsuz kaydirma) + cila + final kurulum rehberi | ✅ bu paket |

### Faz 2'de eklenen iki istek
- **Isteğe bağlı uygulama giriş şifresi:** `SecurityService` + `AppSettings.appLockEnabled`.
  Ayarlardan açılır/kapanır; şifre tuzlanmış SHA-256 ile saklanır. Ayrıca **yönetici
  şifresi** (korumalı işlemler) ve **otomatik kilit** ayarı.
- **Ürün görseli:** `ImageService` ile dükkân sahibi ürün eklerken isteğe bağlı resim
  seçebilir; resim cihaz içine kopyalanır (offline), üründe yalnızca `imagePath` tutulur.
  Satış ekranında ürün kartında gösterilecek (UI Faz 3).

## Eklenen (+) tamamlayici parcalar
Prompttaki yasaklar disinda, bir POS'un eksik kalmamasi icin:
- **Hesap bolme / kismi & bolunmus odeme** (`Payment` koleksiyonu)
- **Urun secenekleri** (porsiyon/ekstra) ve **satir notu** ("acili olmasin")
- **Satir iptali** (sebep ile) ve siparis durum akisi
- **Audit log** (veri butunlugu izi), tum kayitlarda **soft-delete**
- **Tartili satis** opsiyonu (kg) ve odeme yontemi kirilimi (nakit/kart/yemek karti)
- Tum tutarlar **kurus tabanli** (finansal dogruluk)


## Caller ID (Android) kurulum notu

Gelen arama numarasini okuyabilmek icin `android/app/src/main/AndroidManifest.xml`
dosyasina (uygulama olusturulduktan sonra) su izinler eklenmelidir:

```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.READ_CALL_LOG"/>
```

Sonra Ayarlar > Gelen Arama bolumunden ozelligi acin (izin istenir). iOS ve
masaustunde gelen numara okunamaz; bu platformlarda ozellik otomatik devre disidir.


## + Moduller ve Mimari (Kurye, Cagri/Caller ID, Platform siparisleri)

Bu uc istek **yerel ag (LAN) uzerinden** calisir; **bulut kullanilmaz** (offline-first
felsefesiyle uyumlu). Onerilen ve uygulanan mimari:

- **Tek kod tabani, uc rol/giris noktasi.** Ayni proje uc sekilde derlenebilir:
  - `lib/main.dart` -> **Tezgah (ana / ust akil)**: tam POS + yerel ag sunucusu.
  - `lib/main_kurye.dart` -> **Tezgah Kurye** (ince istemci; Isar yok, sadece sunucuya baglanir).
  - `lib/main_cagri.dart` -> **Tezgah Cagri** (telefonda gelen aramayi yakalayip yerel aga gonderir).
  - Ayri APK: `flutter build apk -t lib/main_kurye.dart` gibi.
- **Tezgah ana = ust akil.** Yerel agda bir sunucu (HTTP + WebSocket) acar; esli telefon ve
  kurye uygulamalari ona baglanir. Acip/kapatmak Ayarlar'dan yapilir. Companion uygulamalar
  yalnizca kendi isini yapar, Tezgah'i yonetemez.
- **Cagri (Caller ID over LAN):** Windows'a kurulu Tezgah'a, ayni WiFi'deki telefondan gelen
  arama numarasi aktarilir; Tezgah "su numara ariyor" gosterir, kayitli musteriyle eslestirir.
- **Kurye:** Paket siparisi bir kuryeye atanir. Kurye uygulamasinda ad/soyad/telefon/adres,
  **Adrese Git** ve **Restorana Git** (harita), teslim et, attigi paket sayisi ve fisleri gorunur.
- **Platform siparisleri (Yemeksepeti/Getir vb.):** Gelen kutusu + kabul/iptal/yola cik/teslim akisi.
  Kasa ve muhasebe aynen calismaya devam eder (kabul edilen siparis dahili Order'a baglanir).

### Onemli/durust not: Yemeksepeti gibi platformlarla CANLI entegrasyon
Yemeksepeti/Getir/Trendyol Go'nun **canli siparis akisi** ancak bu platformlarin **resmi
is ortagi (partner) API'leri** ve **internete acik bir webhook ucu** ile alinabilir. Tamamen
yerel (cloud'suz) bir Windows uygulamasi bu akisi dogrudan **alamaz**. Bu yuzden:
- Tezgah'a tam bir **platform siparisleri yonetimi** (gelen kutusu + tum durum akisi) eklenir,
- ayrica yerel sunucuda bir **alim ucu** (`POST /platform/order`) acilir; ileride bir
  koprü/baglayici (partner API'sine sahip kucuk bir bilesen) siparisleri buraya iletebilir.
Boylece Tezgah "platform siparislerini yonet" isini eksiksiz yapar; sadece platformla resmi
baglanti, partner hesabi gerektiren ayri bir adim olarak kalir (durustce belirtiyorum).


### Companion uygulamalari nasil derlenir
Ayni proje, ayri giris noktalariyla derlenir:
```
flutter build apk -t lib/main_cagri.dart   # Tezgah Cagri (Caller ID)
flutter build apk -t lib/main_kurye.dart   # Tezgah Kurye
```
Tezgah ana uygulama her zaman varsayilan `lib/main.dart` ile derlenir.

Cagri kullanimı: Tezgah'ta Ayarlar > Yerel Ag > sunucuyu ac, IP/port/eslesme kodunu gor.
Telefonda Tezgah Cagri uygulamasini ac, bu bilgileri gir, "Dinlemeyi Baslat" de.
Gelen aramada numara Tezgah'a iletilir ve kayitli musteri eslesirse gosterilir.
Android manifest (Cagri): READ_PHONE_STATE + READ_CALL_LOG izinleri gerekir.


### Kurye kullanimı
1. Tezgah: Ayarlar > Yerel Ag > sunucuyu ac ve **Kurye modulu**'nu etkinlestir.
2. Tezgah > Kurye > Kuryeler: kurye ekle (her kuryeye otomatik bir **kurye kodu** verilir).
3. Telefonda Tezgah Kurye uygulamasini ac; IP/port/eslesme kodu + **kurye kodu** gir, Baglan.
4. Tezgah > Kurye > Teslimatlar > "Kuryeye Gonder": paket siparisi sec, bilgileri onayla, kurye ata.
5. Kurye uygulamasinda is gorunur: Ara / Adrese Git / Restorana Git / Yola Ciktim / Teslim Ettim.
   Teslim edilince kuryenin toplam teslimat sayisi artar. (Para/kasa akisi degismez.)


### Platform siparisleri kullanimı
1. Ayarlar > Yerel Ag & Moduller > **Platform siparisleri**'ni acin.
2. Ana menu > **Platform**: Yeni / Aktif / Gecmis sekmeleri.
   - Yeni siparis: **Kabul Et** (dahili paket siparisi olusturulur) / **Reddet**.
   - Aktif: Hazirlaniyor / Yola Cikar / **Teslim Et** / Iptal.
   - **Teslim** edilince bagli siparis "Diger" odeme ile kapanir -> ciro/muhasebe/kasa
     (other satis grubu) akisina girer. Nakit kasaya yazilmaz (platform tahsil eder).
3. **Manuel** siparis: "Siparis Ekle" (telefon siparisi vb.).
4. Yerel alim ucu: `POST /platform/order` (x-tezgah-token). Ileride bir partner-API
   koprusu siparisleri buraya iletebilir; gelen siparis aninda "Yeni" sekmesinde gorunur.

Not: Platform urunleri gercek urun kataloguna bagli olmadigindan maliyet 0 kabul edilir
(kar raporlarinda bu siparisler yuksek marjli gorunur) - bilincli bir basitlestirmedir.


## Kurulum & Calistirma (ozet)

1. **Flutter platformlarini olustur** (ilk sefer):
   ```
   cd tezgah_pos
   flutter create . --platforms=android,ios,windows,macos
   ```
2. **Bagimliliklar:** `flutter pub get`
3. **Isar kod uretimi (zorunlu):**
   ```
   dart run build_runner build --delete-conflicting-outputs
   ```
   (Yeni `*.g.dart` dosyalari uretilir. Faz 12'de Order'a indeksler eklendigi icin
    tekrar calistirilmalidir.)
4. **Ana uygulamayi calistir:** `flutter run` (varsayilan `lib/main.dart`)
5. **Companion APK'lari (istege bagli):**
   ```
   flutter build apk -t lib/main_cagri.dart    # Tezgah Cagri (Caller ID)
   flutter build apk -t lib/main_kurye.dart    # Tezgah Kurye
   ```

### Android izinleri (manifest)
- Cagri: `READ_PHONE_STATE`, `READ_CALL_LOG`
- Yerel ag / companion: `INTERNET` (Flutter'da varsayilan ekli)
- Android 11+ harita/telefon icin `<queries>`'e `tel` ve `https` semalari eklenebilir.

### Moduller (hepsi yerel ag, bulut yok)
Ayarlar > Yerel Ag & Moduller'den acilir: **Gelen arama aktarimi (Cagri)**, **Kurye**,
**Platform siparisleri**. Tezgah ana = ust akil; companion'lar yalnizca baglanir.

### Mimari ozet
- Offline-first, tek cihaz/yerel; veri **Isar**; para **kurus (int)**; tema **Grafit & Kehribar**.
- Modul listesi: Satis/adisyon, Masa, Urun+stok+secenek, Musteri, Kurye, Platform, Muhasebe,
  Kasa (Z raporu), Raporlar (+PDF), Yazdirma (ESC/POS + PDF), Yedekleme (ZIP), Caller ID,
  Yerel ag sunucusu + 2 companion uygulama.

## Faz 13 — Build duzeltme + ayarlanabilir arayuz + ayri uygulamalar (bu paket)
- **Build blocker cozuldu:** Isar -> `isar_community` (AGP 8 / Gradle 8 namespace uyumlu).
  Ayrintili adimlar: `KURULUM_DUZELTME.md`. (build_runner tekrar calistirilmali.)
- **Ayarlanabilir arayuz (Ayarlar > Gorunum):**
  - Aksan tema rengi (Kehribar/Turkuaz/Indigo/Kirmizi/Yesil)
  - Yazi & ikon boyutu (Kucuk/Normal/Buyuk/Cok Buyuk) — tum uygulamaya canli uygulanir
  - Yogunluk (Oto/Ferah/Sikisik) — masaustu/tablet icin
  - Responsive yardimcilari: `Breakpoints` (phone/tablet/desktop)
- **Ayri uygulamalar:** `tezgah_cagri` ve `tezgah_kurye` artik bagimsiz, Isar'siz
  Flutter projeleri olarak da verildi (kendi pubspec + README).

## Yol haritasi (sonraki fazlar — buyuk, dürüst kapsam)
- Windows-oncelikli, **surukle-birak ile yeniden duzenlenebilir / boyutlandirilabilir
  panel (dashboard)** — uzun bas + tasi, tile resize, coklu duzen kaydetme.
- Platforma ozel tam yerlesimler (desktop genis / tablet orta / telefon kompakt).
- **Garson sistemi** + **Mutfak ekrani (KDS, canli yenileme)**.
- Muhasebe/stok/POS/kurye derinlestirme (fire modulu, vardiya, sadakat, QR menu,
  bahsis, split payment ekranlari).
- **Multi-tenant SaaS / paketli kiralama:** DURUSTCE — bu, su anki "offline-first,
  yerel, bulutsuz" mimariyle celisir; gercek kiralama/izolasyon/lisans icin bir
  backend (Firebase/Supabase/kendi API) + lisans katmani gerekir. Mevcut yapida
  "tek kurulum = tek isletme + paket bazli feature toggle" olarak yapilabilir;
  gercek cok-kiracili bulut icin ayri bir mimari turu gerekir.

## Faz 14 — Ozellestirilebilir Panel (Dashboard)
- Yeni **Panel** ana ekrani (acilista ilk bolum). Windows oncelikli, responsive.
- **Duzenle** modu: kartlari **basili tut-surukle** ile yeniden sirala, **boyutlandir**
  (1/2/3 sutun), **gizle**; gizlenenleri sag ustten geri ekle; "Varsayilana dondur".
- Duzen kullanici basina kaydedilir (AppSettings.dashboardLayout - build_runner gerekir).
- Karta dokununca ilgili modul acilir. Mevcut menu/sekmeler aynen korunur (bozulmadi).

## Faz 15 — Garson sistemi + Mutfak ekrani (KDS)
- **Garson akisi:** Adisyon ekraninda **"Mutfaga Gonder"** (ust cubuk). Henuz
  gonderilmemis kalemleri mutfaga yollar; siparis durumu "Hazirlaniyor" olur.
  Sonradan eklenen kalemler tekrar gonderilebilir.
- **Mutfak Ekrani (KDS):** yeni "Mutfak" modulu. Canli ticket panosu (Isar watch):
  - Her masa/paket icin kart; bekleme suresi rozeti (yesil/sari/kirmizi).
  - Satira dokun -> "Hazir"; "Tumu Hazir"; "Servis" -> karti panodan kaldirir.
  - Odenmis/iptal siparisler otomatik gizlenir. Responsive (masaustunde cok sutun).
- Model: `OrderLine`'a `kitchenStatus` (+ sentToKitchenAt/kitchenReadyAt) eklendi,
  `KitchenStatus` enum'u. **build_runner gerekir.**
- Panel + menuye "Mutfak" eklendi; mevcut akislar korundu.

## Faz 16 — Stok derinlestirme (fire + kritik uyari + sayim)
- Yeni **Stok** modulu: sayisal stoklu urunler, canli seviye, arama.
- **Kritik stok uyarisi:** min seviyenin altindaki urun sayisi ust banttan gosterilir,
  tek dokunusla filtrelenir.
- Urun islemleri: **Stok girisi / cikisi / Sayim (gercek miktar) / Fire**.
- **Fire (zayi) modulu** (Ayarlar > Stok / Fire ile ac/kapa). Acikken fire kaydi stoku
  duser; istege bagli olarak maliyet uzerinden **otomatik gider** kaydi olusturur.
- Model: `StockMovementType.waste` + ayar alanlari eklendi. **build_runner gerekir.**
