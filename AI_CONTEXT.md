# Biz İdeal Cennetine - Project Structure & AI Context

Bu dosya, projeyi anlamak ve yeni özellikler eklemek için AI modellerine (ve geliştiricilere) derinlemesine bağlam sağlar. lütfen projeye ekleme çıkarma yaptıkça bu dosyayı güncel tut.

## 🌟 Proje Özeti
**Biz İdeal Cennetine**, "Ateş-i Aşk" serisi üzerine kurulu, manevi bir müzik ve meditasyon uygulamasıdır. Kullanıcılara dinleme listeleri, beğeni senkronizasyonu (web/TV ile) ve görsel bir deneyim sunar.

---

## 📂 Dizin Yapısı

### 1. `lib/` (Kök)
- **`main.dart`**: Uygulamanın giriş noktası. `MyApp`, `SplashScreen` süreçlerini ve global servislerin (`AudioService`, `AppLinks`) başlatılmasını yönetir.

### 2. `lib/screens/` (Sayfa Seviyesi Bileşenler)
- **`main_screen.dart`**: Uygulamanın ana iskeleti. `IndexedStack` kullanarak sekmeler arasında geçiş yapar. `MyCustomLayout` ana stack yapısını tutar.
- **`playlist_screen.dart`**: `ListeWidget` sınıfını içerir. Şarkı listesini (Hazine) ve beğenilenleri (Dokunanlar) yan yana split-view şeklinde gösterir. Arama alanı altta sabittir.
- **`discovery_screen.dart`**: `DinlemeListesiWidget` sınıfını içerir. Sunucudan gelen farklı çalma listelerini seçmeye yarayan dropdown ve detay ekranıdır.

### 3. `lib/widgets/` (Görsel ve Yardımcı Bileşenler)
- **`visuals.dart`**: `KenBurnsViewWidget` (kayan resim efekti), `AkanYazi` (text scroll), `Base64ImageWidget` (dinamik resim indirme) ve `LoadingWidget` bileşenlerini içerir.
- **`confetti.dart`**: Beğeni veya özel anlarda tetiklenen matematiksel kalp konfeti animasyonunu içerir. `ImprovedConfettiDemo` bu animasyonu sarmalar.
- **`dialogs.dart`**: `CustomDialog` bileşeni. Bildirimler ve hediye şarkı mesajları için özel siyah stil penceredir.
- **`settings_menu.dart`**: Tema seçimi, senkronizasyon izleme ve çıkış işlemlerini birleştiren üst seviye ayarlar menüsü.
- **`splash_screen.dart`**: Uygulama açılışındaki logolu ve animasyonlu ekran.

### 4. `lib/yaveran/` (Core Servisler ve Destek Sistemleri)
- **`Degiskenler.dart`**: Global Singleton State. Tüm notifiers (`ValueNotifier`), temalar (`AppTheme` - Sükun, Gece, Vaha, Gül, Zümrüt, Kehribar, Lale, Sema, Mor, Toprak, Buzul, Orman, Kiraz, Uzay, Aura) ve statik ayarlar buradadır.
- **`logic.dart`**: İş mantığı katmanı. Veri çekme (`fetchData_json...`), çalma listesi hazırlama (`setPlaylist`) ve derin link (`initUniLinks`) işlemlerini yönetir.
- **`audio_service.dart`**: `just_audio` ve `audio_service` paketlerinin üzerine kurulu, arka planda müzik çalma, bildirim kontrolü ve oynatma listesi yönetimini sağlayan statik `AudioService` sınıfıdır.
- **`MusicApiService.dart`**: JWT tabanlı kimlik doğrulama, beğeni senkronizasyonu (`toggleLike`, `fetchMyLikes`) ve TV/Web eşleştirme kodlarını yöneten API servisi.
- **`widgets.dart`**: Oynatıcı kontrolleri (`PlayButton`, `Seekbar`, `AudioControlButtons`) ve kullanıcı senkronizasyon durumu simgesi (`UserSyncIcon`) gibi teknik widget'ları içerir.
- **`HttpService.dart` & `JsonHelper.dart`**: Düşük seviyeli ağ ve JSON ayrıştırma yardımcıları.
- **`ui_support.dart`**: Ekran boyutlarını (`altEkranBoyutNotifier`) ve görsel içerikleri değiştiren yardımcı fonksiyonlar.

---

## 🔗 Dosya İlişkileri & Bağımlılıklar

### Veri Akışı
1. `logic.dart` veriyi çeker -> `Degiskenler` içindeki notifiers güncellenir.
2. `MainScreen` veya ilgili ekran bu notifiers'ları dinler ve arayüzü günceller.

### Oynatıcı Akışı
1. `widgets.dart` üzerindeki butonlar -> `AudioService` (yaveran) metodlarını çağırır.
2. `AudioService` -> `MyAudioHandler` (arka plan) üzerinden `just_audio` player'ı tetikler.
3. Player durumu değiştikçe `AudioService` içindeki notifiers (`playButtonNotifier` vb.) güncellenir.

### Bağımlılık Matrisi
- **`main.dart`** -> `logic.dart`, `splash_screen.dart`, `main_screen.dart`
- **`main_screen.dart`** -> `widgets.dart` (yaveran), `visuals.dart`, `confetti.dart`, `playlist_screen.dart`, `discovery_screen.dart`
- **`playlist_screen.dart` & `discovery_screen.dart`** -> `logic.dart`, `MusicApiService.dart`, `Degiskenler.dart`
- **`widgets.dart` (yaveran)** -> `AudioService.dart`, `MusicApiService.dart`, `ui_support.dart`

---

## 📝 AI İçin Önemli Notlar (AI-CONTEXT)
- **Tema Yönetimi**: `AppTheme` içinde 3 ana tema var (Sükun, Gece, Vaha). Görsel değişiklikler `Degiskenler.currentThemeNotifier` üzerinden yapılır.
- **Ekran Bölme**: `altEkranBoyutNotifier` ve `ustEkranBoyutNotifier` toplamı 100 olmalıdır. Oynatıcı yukarı kaydırıldığında (`altEkranBoyut` artar), kontroller genişler.
- **Görseller**: Uygulama resimleri local assets yerine `Degiskenler.kaynakYolu` üzerinden GitHub raw linkiyle dinamik olarak çekilir.
- **Terminoloji**: 
  - *Hazine*: Ana şarkı listesi.
  - *Dokunanlar*: Kullanıcının beğendiği şarkılar.
  - *Yaveran*: Yardımcı/Destek servisler klasörü.
