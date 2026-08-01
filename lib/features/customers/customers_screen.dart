import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/money.dart';
import '../../data/collections/people_collections.dart';
import '../shared/widgets.dart';

// --- TÜRKİYE'NİN TÜM İLLERİ VE İLÇELERİ VERİ TABANI ---
const Map<String, List<String>> turkiyeSehirlerIlceler = {
  "Adana": [
    "Aladağ", "Ceyhan", "Çukurova", "Feke", "İmamoğlu", "Karaisalı", "Kozan", 
    "Pozantı", "Saimbeyli", "Sarıçam", "Seyhan", "Tufanbeyli", "Yumurtalık", "Yüreğir"
  ],
  "Adıyaman": [
    "Besni", "Çelikhan", "Gerger", "Gölbaşı", "Kâhta", "Merkez", "Samsat", "Sincik", "Tut"
  ],
  "Afyonkarahisar": [
    "Başmakçı", "Bayat", "Bolvadin", "Çay", "Çobanlar", "Dazkırı", "Dinar", 
    "Emirdağ", "Evciler", "Hocalar", "İhsaniye", "İscehisar", "Kızılören", 
    "Merkez", "Sinanpaşa", "Sultandağı", "Şuhut"
  ],
  "Ağrı": [
    "Diyadin", "Doğubayazıt", "Eleşkirt", "Hamur", "Merkez", "Patnos", "Taşlıçay", "Tutak"
  ],
  "Amasya": [
    "Göynücek", "Gümüşhacıköy", "Hamamözü", "Merkez", "Merzifon", "Suluova", "Taşova"
  ],
  "Ankara": [
    "Akyurt", "Altındağ", "Ayaş", "Bala", "Beypazarı", "Çamlıdere", "Çankaya", 
    "Çubuk", "Elmadağ", "Etimesgut", "Evren", "Gölbaşı", "Güdül", "Haymana", 
    "Kahramankazan", "Kalecik", "Keçiören", "Kızılcahamam", "Mamak", "Nallıhan", 
    "Polatlı", "Pursaklar", "Sincan", "Şereflikoçhisar", "Yenimahalle"
  ],
  "Antalya": [
    "Akseki", "Aksu", "Alanya", "Demre", "Döşemealtı", "Elmalı", "Finike", 
    "Gazipaşa", "Gündoğmuş", "İbradı", "Kaş", "Kemer", "Kepez", "Konyaaltı", 
    "Korkuteli", "Kumluca", "Manavgat", "Muratpaşa", "Serik"
  ],
  "Artvin": [
    "Ardanuç", "Arhavi", "Borçka", "Hopa", "Kemalpaşa", "Merkez", "Murgul", "Şavsat", "Yusufeli"
  ],
  "Aydın": [
    "Bozdoğan", "Buharkent", "Çine", "Didim", "Efeler", "Germencik", "İncirliova", 
    "Karacasu", "Karpuzlu", "Koçarlı", "Köşk", "Kuşadası", "Kuyucak", "Nazilli", 
    "Söke", "Sultanhisar", "Yenipazar"
  ],
  "Balıkesir": [
    "Altıeylül", "Ayvalık", "Balya", "Bandırma", "Bigadiç", "Burhaniye", "Dursunbey", 
    "Edremit", "Erdek", "Gömeç", "Gönen", "Havran", "İvrindi", "Karesi", "Kepsut", 
    "Manyas", "Marmara", "Savaştepe", "Sındırgı", "Susurluk"
  ],
  "Bilecik": [
    "Bozüyük", "Gölpazarı", "İnhisar", "Merkez", "Osmaneli", "Pazaryeri", "Söğüt", "Yenipazar"
  ],
  "Bingöl": [
    "Adaklı", "Genç", "Karlıova", "Kiğı", "Merkez", "Solhan", "Yayladere", "Yedisu"
  ],
  "Bitlis": [
    "Adilcevaz", "Ahlat", "Güroymak", "Hizan", "Merkez", "Mutki", "Tatvan"
  ],
  "Bolu": [
    "Dörtdivan", "Gerede", "Göynük", "Kıbrıscık", "Mengen", "Merkez", "Mudurnu", "Seben", "Yeniçağa"
  ],
  "Burdur": [
    "Ağlasun", "Altınyayla", "Bucak", "Çavdır", "Çeltikçi", "Gölhisar", "Karamanlı", 
    "Kemer", "Merkez", "Tefenni", "Yeşilova"
  ],
  "Bursa": [
    "Büyükorhan", "Gemlik", "Gürsu", "Harmancık", "İnegöl", "İznik", "Karacabey", 
    "Keles", "Kestel", "Mudanya", "Mustafakemalpaşa", "Nilüfer", "Orhaneli", 
    "Orhangazi", "Osmangazi", "Yenişehir", "Yıldırım"
  ],
  "Çanakkale": [
    "Ayvacık", "Bayramiç", "Biga", "Bozcaada", "Çan", "Eceabat", "Ezine", 
    "Gelibolu", "Gökçeada", "Lapseki", "Merkez", "Yenice"
  ],
  "Çankırı": [
    "Atkaracalar", "Bayramören", "Çerkeş", "Eldivan", "Ilgaz", "Kızılırmak", 
    "Korgun", "Kurşunlu", "Merkez", "Orta", "Şabanözü", "Yapraklı"
  ],
  "Çorum": [
    "Alaca", "Bayat", "Boğazkale", "Dodurga", "İskilip", "Kargı", "Laçin", 
    "Mecitözü", "Merkez", "Oğuzlar", "Ortaköy", "Osmancık", "Sungurlu", "Uğurludağ"
  ],
  "Denizli": [
    "Acıpayam", "Babadağ", "Baklan", "Bekilli", "ağaçüstü", "Bozkurt", "Buldan", 
    "Çal", "Çameli", "Çardak", "Çivril", "Güney", "Honaz", "Kale", "Merkezefendi", 
    "Pamukkale", "Sarayköy", "Serinhisar", "Tavas"
  ],
  "Diyarbakır": [
    "Bağlar", "Bismil", "Çermik", "Çınar", "Çüngüş", "Dicle", "Eğil", "Ergani", 
    "Hani", "Hazro", "Kayapınar", "Kocaköy", "Kulp", "Lice", "Silvan", "Sur", "Yenişehir"
  ],
  "Edirne": [
    "Enez", "Havsa", "İpsala", "Keşan", "Lüleburgaz", "Meriç", "Merkez", "Süloğlu", "Uzunköprü"
  ],
  "Elazığ": [
    "Ağın", "Alacakaya", "Arıcak", "Baskil", "Karakoçan", "Keban", "Kovancılar", 
    "Maden", "Merkez", "Palu", "Sivrice"
  ],
  "Erzincan": [
    "Çayırlı", "İliç", "Kemah", "Kemaliye", "Merkez", "Otlukbeli", "Refahiye", "Tercan", "Üzümlü"
  ],
  "Erzurum": [
    "Aşkale", "Aziziye", "Çat", "Hınıs", "Horasan", "İspir", "Karaçoban", "Karayazı", 
    "Köprüköy", "Narman", "Oltu", "Olur", "Palandöken", "Pasinler", "Pazaryolu", 
    "Şenkaya", "Tortum", "Uzundere", "Yakutiye"
  ],
  "Eskişehir": [
    "Alpu", "Beylikova", "Çifteler", "Günyüzü", "Han", "İnönü", "Mahmudiye", 
    "Mihalgazi", "Mihalıççık", "Odunpazarı", "Sarıcakaya", "Sivrihisar", "Tepebaşı"
  ],
  "Gaziantep": [
    "Araban", "İslahiye", "Karkamış", "Nizip", "Nurdağı", "Oğuzeli", "Şahinbey", "Şehitkamil", "Yavuzeli"
  ],
  "Giresun": [
    "Alucra", "Bulancak", "Çamoluk", "Çanakçı", "Dereli", "Doğankent", "Espiye", 
    "Eynesil", "Görele", "Güce", "Keşap", "Merkez", "Piraziz", "Şebinkarahisar", 
    "Tirebolu", "Yağlıdere"
  ],
  "Gümüşhane": [
    "Kelkit", "Köse", "Kürtün", "Merkez", "Şiran", "Torul"
  ],
  "Hakkâri": [
    "Çukurca", "Derecik", "Merkez", "Şemdinli", "Yüksekova"
  ],
  "Hatay": [
    "Altınözü", "Antakya", "Arsuz", "Belen", "Defne", "Dörtyol", "Erzin", 
    "Hassa", "İskenderun", "Kırıkhan", "Kumlu", "Payas", "Reyhanlı", "Samandağ", "Yayladağı"
  ],
  "Isparta": [
    "Aksu", "Atabey", "Eğirdir", "Gelendost", "Gönen", "Keçiborlu", "Merkez", 
    "Senirkent", "Sütçüler", "Şarkikaraağaç", "Uluborlu", "Yalvaç", "Yenişarbademli"
  ],
  "Mersin": [
    "Akdeniz", "Anamur", "Aydıncık", "Bozyazı", "Çamlıyayla", "Erdemli", "Gülnar", 
    "Mezitli", "Mut", "Silifke", "Tarsus", "Toroslar", "Yenişehir"
  ],
  "İstanbul": [
    "Adalar", "Arnavutköy", "Ataşehir", "Avcılar", "Bağcılar", "Bahçelievler", 
    "Bakırköy", "Başakşehir", "Bayrampaşa", "Beşiktaş", "Beykoz", "Beylikdüzü", 
    "Beyoğlu", "Büyükçekmece", "Çatalca", "Çekmeköy", "Esenler", "Esenyurt", 
    "Eyüpsultan", "Fatih", "Gaziosmanpaşa", "Güngören", "Kadıköy", "Kağıthane", 
    "Kartal", "Küçükçekmece", "Maltepe", "Pendik", "Sancaktepe", "Sarıyer", 
    "Silivri", "Sultanbeyli", "Sultangazi", "Şile", "Şişli", "Tuzla", "Ümraniye", 
    "Üsküdar", "Zeytinburnu"
  ],
  "İzmir": [
    "Aliağa", "Balçova", "Bayındır", "Bayraklı", "Bergama", "Beydağ", "Bornova", 
    "Buca", "Çeşme", "Çiğli", "Dikili", "Foça", "Gaziemir", "Güzelbahçe", 
    "Karabağlar", "Karaburun", "Karşıyaka", "Kemalpaşa", "Kınık", "Kiraz", 
    "Konak", "Menderes", "Menemen", "Narlıdere", "Ödemiş", "Seferihisar", 
    "Selçuk", "Tire", "Torbalı", "Urla"
  ],
  "Kars": [
    "Akyaka", "Arpaçay", "Digor", "Kağızman", "Merkez", "Sarıkamış", "Selim", "Susuz"
  ],
  "Kastamonu": [
    "Abana", "Ağlı", "Araç", "Azdavay", "Bozkurt", "Cide", "Çatalzeytin", "Daday", 
    "Devrekani", "İhsangazi", "İnebolu", "Küre", "Merkez", "Pınarbaşı", "Seydiler", 
    "Şenpazar", "Taşköprü", "Tosya"
  ],
  "Kayseri": [
    "Akkışla", "Bünyan", "Develi", "Fecirli", "Hacılar", "İncesu", "Kocasinan", 
    "Melikgazi", "Özvatan", "Pınarbaşı", "Sarıoğlan", "Sarız", "Talas", "Tomarza", 
    "Yahyalı", "Yeşilhisar"
  ],
  "Kırklareli": [
    "Babaeski", "Demirköy", "Kofçaz", "Lüleburgaz", "Merkez", "Pehlivanköy", "Pınarhisar", "Vize"
  ],
  "Kırşehir": [
    "Akçakent", "Akpınar", "Boztepe", "Çiçekdağı", "Kaman", "Merkez", "Mucur"
  ],
  "Kocaeli": [
    "Başiskele", "Çayırova", "Darıca", "Derince", "Dilovası", "Gebze", "Gölcük", 
    "İzmit", "Kandıra", "Karamürsel", "Kartepe", "Körfez"
  ],
  "Konya": [
    "Ahırlı", "Akören", "Akşehir", "Altınekin", "Beyşehir", "Bozkır", "Cihanbeyli", 
    "Çeltik", "Çumra", "Derbent", "Derebucak", "Doğanhisar", "Emirgazi", "Ereğli", 
    "Güneysınır", "Hadim", "Halkapınar", "Hüyük", "Ilgın", "Kadınhanı", "Karapınar", 
    "Karatay", "Kulu", "Meram", "Sarayönü", "Selçuklu", "Seydişehir", "Taşkent", 
    "Tuzlukçu", "Yalıhüyük", "Yunak"
  ],
  "Kütahya": [
    "Altıntaş", "Aslanapa", "Çavdarhisar", "Domaniç", "Dumlupınar", "Emet", 
    "Gediz", "Hisarcık", "Merkez", "Pazarlar", "Şaphane", "Simav", "Tavşanlı"
  ],
  "Malatya": [
    "Akçadağ", "Arapkir", "Arguvan", "Battalgazi", "Darende", "Doğanşehir", 
    "Doğanyol", "Hekimhan", "Kale", "Kuluncak", "Pütürge", "Yazıhan", "Yeşilyurt"
  ],
  "Manisa": [
    "Ahmetli", "Akhisar", "Alaşehir", "Demirci", "Gölmarmara", "Gördes", "Kırkağaç", 
    "Köprübaşı", "Kula", "Salihli", "Sarıgöl", "Saruhanlı", "Selendi", "Soma", 
    "Şehzadeler", "Turgutlu", "Yunusemre"
  ],
  "Kahramanmaraş": [
    "Afşin", "Andırın", "Çağlayancerit", "Dulkadiroğlu", "Ekinözü", "Elbistan", 
    "Göksun", "Nurhak", "Onikişubat", "Pazarcık", "Türkoğlu"
  ],
  "Mardin": [
    "Artuklu", "Dargeçit", "Derik", "Kızıltepe", "Mazıdağı", "Midyat", "Nusaybin", "Ömerli", "Savur", "Yeşilli"
  ],
  "Muğla": [
    "Bodrum", "Dalaman", "Datça", "Fethiye", "Kavaklıdere", "Köyceğiz", "Marmaris", 
    "Menteşe", "Milas", "Ortaca", "Seydikemer", "Ula", "Yatağan"
  ],
  "Muş": [
    "Bulanık", "Hasköy", "Korkut", "Malazgirt", "Merkez", "Varto"
  ],
  "Nevşehir": [
    "Acıgöl", "Avanos", "Derinkuyu", "Gülşehir", "Hacıbektaş", "Kozaklı", "Merkez", "Ürgüp"
  ],
  "Niğde": [
    "Altunhisar", "Bor", "Çamardı", "Çiftlik", "Merkez", "Ulukışla"
  ],
  "Ordu": [
    "Akkuş", "Altınordu", "Aybastı", "Çamaş", "Çatalpınar", "Çaybaşı", "Fatsa", 
    "Gölköy", "Gülyalı", "Gürgentepe", "İkizce", "Kabadüz", "Kabataş", "Korgan", 
    "Kumru", "Mesudiye", "Perşembe", "Ulubey", "Ünye"
  ],
  "Rize": [
    "Ardeşen", "Çamlıhemşin", "Çayeli", "Derepazarı", "Fındıklı", "Güneysu", 
    "Hemşin", "İkizdere", "İyidere", "Kalkandere", "Merkez", "Pazar"
  ],
  "Sakarya": [
    "Akyazı", "Arifiye", "Erenler", "Ferizli", "Geyve", "Hendek", "Karapürçek", 
    "Karasu", "Kaynarca", "Kocaali", "Pamukova", "Sapanca", "Serdivan", "Söğütlü", "Taraklı"
  ],
  "Samsun": [
    "19 Mayıs", "Alaçam", "Asarcık", "Atakum", "Ayvacık", "Bafra", "Canik", 
    "Çarşamba", "Havza", "Kavak", "Ladik", "Salıpazarı", "Tekkeköy", "Terme", "Vezirköprü", "Yakakent"
  ],
  "Siirt": [
    "Baykan", "Eruh", "Hizan", "Kurtalan", "Merkez", "Pervari", "Şirvan"
  ],
  "Sinop": [
    "Ayancık", "Boyabat", "Dikmen", "Durağan", "Erfelek", "Gerze", "Merkez", "Saraydüzü", "Türkeli"
  ],
  "Sivas": [
    "Akıncılar", "Altınyayla", "Divriği", "Doğanşar", "Gemerek", "Gölova", 
    "Hafik", "İmranlı", "Kangal", "Koyulhisar", "Merkez", "Suşehri", "Şarkışla", 
    "Ulaş", "Yıldızeli", "Zara"
  ],
  "Tekirdağ": [
    "Çerkezköy", "Çorlu", "Ergene", "Hayrabolu", "Kapaklı", "Malkara", "Marmaraereğlisi", 
    "Muratlı", "Saray", "Süleymanpaşa", "Şarköy"
  ],
  "Tokat": [
    "Almus", "Artova", "Başçiftlik", "Erbaa", "Niksar", "Pazar", "Reşadiye", 
    "Sulusaray", "Turhal", "Yeşilyurt", "Zile"
  ],
  "Trabzon": [
    "Akçaabat", "Araklı", "Arsin", "Beşikdüzü", "Çarşıbaşı", "Çaykara", "Dernekpazarı", 
    "Düzköy", "Hayrat", "Köprübaşı", "Maçka", "Of", "Ortahisar", "Sürmene", 
    "Şalpazarı", "Tonya", "Vakfıkebir", "Yomra"
  ],
  "Tunceli": [
    "Çemişgezek", "Hozat", "Mazgirt", "Merkez", "Ovacık", "Pertek", "Pülümür"
  ],
  "Şanlıurfa": [
    "Akçakale", "Birecik", "Bozova", "Ceylanpınar", "Eyyübiye", "Halfeti", 
    "Haliliye", "Harran", "Hilvan", "Siverek", "Suruç", "Viranşehir"
  ],
  "Uşak": [
    "Banaz", "Eşme", "Sivaslı", "Stabaz", "Merkez", "Ulubey"
  ],
  "Van": [
    "Bahçesaray", "Başkale", "Çaldıran", "Çatak", "Edremit", "Erciş", "Gevaş", 
    "Gürpınar", "Muradiye", "Özalp", "Saray", "Tuşba"
  ],
  "Yozgat": [
    "Akdağmadeni", "Aydıncık", "Boğazlıyan", "Çandır", "Çayıralan", "Çekerek", 
    "Kadışehri", "Merkez", "Saraykent", "Sarıkaya", "Sorgun", "Şefaatli", "Yenifakılı", "Yerköy"
  ],
  "Zonguldak": [
    "Alaplı", "Çaycuma", "Devrek", "Gökçebey", "Karadeniz Ereğli", "Merkez"
  ],
  "Aksaray": [
    "Ağaçören", "Eskil", "Gülağaç", "Güzelyurt", "Merkez", "Ortaköy", "Sarıyahşi"
  ],
  "Bayburt": [
    "Aydıntepe", "Demirözü", "Merkez"
  ],
  "Karaman": [
    "Ayrancı", "Basyayla", "Ermenek", "Kâzımkarabekir", "Merkez", "Sarıveliler"
  ],
  "Kırıkkale": [
    "Bahşılı", "Balışeyh", "Çelebi", "Delice", "Karakeçili", "Keskin", "Merkez", "Sulakyurt", "Yahşihan"
  ],
  "Batman": [
    "Beşiri", "Gercüş", "Hasankeyf", "Kozluk", "Merkez", "Sason"
  ],
  "Şırnak": [
    "Beytüşşebap", "Cizre", "Güçlükonak", "İdil", "Merkez", "Silopi", "Uludere"
  ],
  "Bartın": [
    "Amasra", "Kurucaşile", "Merkez", "Ulus"
  ],
  "Ardahan": [
    "Çıldır", "Damal", "Göle", "Hanak", "Merkez", "Posof"
  ],
  "Iğdır": [
    "Aralık", "Karakoyunlu", "Merkez", "Tuzluca"
  ],
  "Yalova": [
    "Altınova", "Armutlu", "Çınarcık", "Çiftlikköy", "Merkez", "Termal"
  ],
  "Karabük": [
    "Eflani", "Eskipazar", "Merkez", "Ovacık", "Safranbolu", "Yenice"
  ],
  "Kilis": [
    "Elbeyli", "Merkez", "Musabeyli", "Polateli"
  ],
  "Osmaniye": [
    "Bahçe", "Düziçi", "Hasanbeyli", "Kadirli", "Merkez", "Sumbas"
  ],
  "Düzce": [
    "Akçakoca", "Cumayeri", "Çilimli", "Gümüşova", "Kaynaşlı", "Merkez", "Yığılca"
  ]
};

// Türkçe alfabetik sıralama fonksiyonu (Ç, İ, Ş gibi karakterleri doğru konuma koyar)
int _turkceKarsilastir(String a, String b) {
  String normalize(String s) {
    return s.toLowerCase()
        .replaceAll('İ', 'i').replaceAll('ı', 'i')
        .replaceAll('Ç', 'c').replaceAll('ç', 'c')
        .replaceAll('Ş', 's').replaceAll('ş', 's')
        .replaceAll('Ğ', 'g').replaceAll('ğ', 'g')
        .replaceAll('Ö', 'o').replaceAll('ö', 'o')
        .replaceAll('Ü', 'u').replaceAll('ü', 'u');
  }
  return normalize(a).compareTo(normalize(b));
}

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) formatted += ' ';
      formatted += digits[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  static const _pageSize = 40;

  List<Customer> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
    });
    final list = await ref
        .read(customerRepositoryProvider)
        .page(search: _query, offset: 0, limit: _pageSize);
    if (mounted) {
      setState(() {
        _items = list;
        _offset = list.length;
        _hasMore = list.length == _pageSize;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final more = await ref
        .read(customerRepositoryProvider)
        .page(search: _query, offset: _offset, limit: _pageSize);
    if (mounted) {
      setState(() {
        _items = [..._items, ...more];
        _offset += more.length;
        _hasMore = more.length == _pageSize;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Müşteriler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Müşteri Ekle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'İsim, telefon veya müşteri no ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _query = '';
                          _load();
                        },
                      ),
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline_rounded,
                        message: _query.isEmpty
                            ? 'Henüz müşteri yok.'
                            : 'Sonuç bulunamadı.',
                      )
                    : ListView.separated(
                        controller: _scroll,
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          if (i >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(
                                  child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            );
                          }
                          final c = _items[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.amber.withValues(alpha: 0.2),
                              child: Text(
                                _initials(c),
                                style: const TextStyle(
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Row(
                              children: [
                                if (c.customerNumber != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${c.customerNumber}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.amber,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    c.fullName.isEmpty ? '(İsimsiz)' : c.fullName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text([
                              if (c.phone.isNotEmpty) c.phone,
                              '${c.totalOrders} sipariş',
                              Money.format(c.totalSpendKurus),
                            ].join(' • ')),
                            trailing: c.lastOrderAt == null
                                ? null
                                : Text(DateX.dmy.format(c.lastOrderAt!),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                            onTap: () => _edit(c),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _initials(Customer c) {
    final f = c.firstName.isNotEmpty ? c.firstName[0] : '';
    final l = c.lastName.isNotEmpty ? c.lastName[0] : '';
    final s = (f + l).toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Future<void> _edit(Customer? existing) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CustomerFormScreen(existing: existing),
    );
    if (changed == true) _load();
  }
}

// ============================================================================
// GELİŞMİŞ MÜŞTERİ EKLEME / DÜZENLEME FORMU (Konum + Türkiye İl/İlçe + Harita)
// ============================================================================
class CustomerFormScreen extends ConsumerStatefulWidget {
  final Customer? existing;
  const CustomerFormScreen({super.key, this.existing});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _customerNumberCtrl;
  late final TextEditingController _countryCode;
  late final TextEditingController _phone;

  // Yapılandırılmış Harita Adres Alanları
  late final TextEditingController _mahalle;
  late final TextEditingController _cadde;
  late final TextEditingController _binaNo;
  
  String? _secilenIl;
  String? _secilenIlce;
  List<String> _mevcutIlceler = [];

  // İlleri Türkçe alfabeye göre sıralı başlatıyoruz
  late final List<String> _siraliIller = turkiyeSehirlerIlceler.keys.toList()
    ..sort(_turkceKarsilastir);

  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _first = TextEditingController(text: e?.firstName ?? '');
    _last = TextEditingController(text: e?.lastName ?? '');
    _customerNumberCtrl = TextEditingController(text: e?.customerNumber?.toString() ?? '');
    
    _countryCode = TextEditingController(text: '+90');
    _phone = TextEditingController(text: e?.phone ?? '');
    
    _mahalle = TextEditingController();
    _cadde = TextEditingController();
    _binaNo = TextEditingController();

    // Mevcut adres metnini parçalayıp kutulara yerleştirme
    if (e?.address != null && e!.address.isNotEmpty) {
      final parts = e.address.split(',');
      for (var part in parts) {
        final p = part.trim();
        if (p.contains('Mah')) {
          _mahalle.text = p.replaceAll('Mah.', '').trim();
        } else if (p.contains('Sok') || p.contains('Cad')) {
          _cadde.text = p.replaceAll('Sok.', '').replaceAll('Cad.', '').trim();
        } else if (p.contains('No:')) {
          _binaNo.text = p.replaceAll('No:', '').trim();
        }
      }
    }

    _note = TextEditingController(text: e?.note ?? '');
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (widget.existing == null && _customerNumberCtrl.text.isEmpty) {
      final list = await ref.read(customerRepositoryProvider).page(search: '', offset: 0, limit: 1000);
      if (mounted) {
        setState(() => _customerNumberCtrl.text = (list.length + 1).toString());
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _customerNumberCtrl, _countryCode, _phone, _mahalle, _cadde, _binaNo, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _getCurrentLocationAndFill() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum servisleri kapalı!')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛰️ Uydudan konum alınıyor...'), duration: Duration(seconds: 2)),
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _mahalle.text = place.subLocality ?? place.locality ?? place.name ?? '';
          _cadde.text = place.thoroughfare ?? place.street ?? '';
          _binaNo.text = place.subThoroughfare ?? '';

          String? bulunanIl = place.administrativeArea;
          if (bulunanIl != null) {
            for (String ilKey in turkiyeSehirlerIlceler.keys) {
              if (bulunanIl.toLowerCase().contains(ilKey.toLowerCase())) {
                _secilenIl = ilKey;
                _mevcutIlceler = List.from(turkiyeSehirlerIlceler[ilKey] ?? [])
                  ..sort(_turkceKarsilastir);
                break;
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Konum alınamadı: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      
      String rawPhoneDigits = _phone.text.replaceAll(RegExp(r'\D'), '');
      if (rawPhoneDigits.startsWith('0') && rawPhoneDigits.length > 10) {
        rawPhoneDigits = rawPhoneDigits.substring(1);
      }
      final String fullPhone = '${_countryCode.text.trim()}$rawPhoneDigits';

      final String builtAddress = [
        if (_mahalle.text.trim().isNotEmpty) '${_mahalle.text.trim()} Mah.',
        if (_cadde.text.trim().isNotEmpty) '${_cadde.text.trim()} Cad./Sok.',
        if (_binaNo.text.trim().isNotEmpty) 'No:${_binaNo.text.trim()}',
        if (_secilenIlce != null) _secilenIlce,
        if (_secilenIl != null) _secilenIl,
      ].join(', ');

      final c = widget.existing ?? Customer();
      c
        ..customerNumber = int.tryParse(_customerNumberCtrl.text.trim())
        ..firstName = _first.text.trim()
        ..lastName = _last.text.trim()
        ..phone = fullPhone
        ..address = builtAddress
        ..note = _note.text.trim()
        ..updatedAt = DateTime.now();

      if (widget.existing == null) {
        c.createdAt = DateTime.now();
      }

      await repo.save(c);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Müşteri silinsin mi?'),
        content: Text(widget.existing!.fullName),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(customerRepositoryProvider).softDelete(widget.existing!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Müşteri Düzenle' : 'Müşteri Ekle'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
          ),
          children: [
            SizedBox(
              width: 140,
              child: TextFormField(
                controller: _customerNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Müşteri No',
                  hintText: 'Örn: 1, 59',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Ad'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad zorunludur' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Soyad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _countryCode,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Kod'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      PhoneNumberFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Telefon Numarası',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Telefon zorunludur' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _getCurrentLocationAndFill,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Konumu Bul (Nokta Atışı)'),
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mahalle,
                    decoration: const InputDecoration(labelText: 'Mahalle'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _cadde,
                    decoration: const InputDecoration(labelText: 'Cadde / Sokak'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _binaNo,
                    decoration: const InputDecoration(labelText: 'Kapı No'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _secilenIl,
                    decoration: const InputDecoration(labelText: 'İl'),
                    hint: const Text('İl Seçin'),
                    isExpanded: true,
                    items: _siraliIller
                        .map((il) => DropdownMenuItem(value: il, child: Text(il)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _secilenIl = val;
                        _secilenIlce = null;
                        _mevcutIlceler = List.from(turkiyeSehirlerIlceler[val!] ?? [])
                          ..sort(_turkceKarsilastir);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            DropdownButtonFormField<String>(
              value: _secilenIlce,
              decoration: const InputDecoration(labelText: 'İlçe'),
              hint: const Text('Önce İl Seçin'),
              isExpanded: true,
              items: _mevcutIlceler
                  .map((ilce) => DropdownMenuItem(value: ilce, child: Text(ilce)))
                  .toList(),
              onChanged: (val) => setState(() => _secilenIlce = val),
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Özel Notlar'),
            ),
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Müşteriyi Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}