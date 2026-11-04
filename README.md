# AGS Asistanı

MEB **Akademi Giriş Sınavı (AGS)** ve **Öğretmenlik Alan Bilgisi Testi (ÖABT)** adayları için Flutter ile yazılmış
bir çalışma asistanı ve not uygulaması. Pomodoro ile çalışma takibi, resmî müfredata göre konu takibi, 7. / 30. gün
tekrar sistemi, deneme analizi, ajanda ve renkli notlar tek uygulamada.

## Özellikler

- **Panel:** AGS geri sayımı ve resmî sınav takvimi, günlük hedef halkası, çalışma serisi, haftalık grafik,
  ders bazında konu ilerlemesi, tekrar uyarıları.
- **Pomodoro / Kronometre:**
  - Bildirim çubuğunda canlı geri sayım.
  - Süre dolunca tam zamanında titreşimli alarm ve konfeti.
  - Telefon kilitliyse kilit ekranında yalnızca sade bir "Süre doldu" ekranı gösterilir.
  - Oturum sonunda "soru mu çözdün, konu mu çalıştın?" kaydı.
- **Konular:**
  - ÖSYM 2026 konu dağılımına göre AGS + 17 ÖABT alanı; konu başına ağırlık ve yaklaşık soru sayısı.
  - Biten konu için 7. ve 30. gün tekrarları otomatik planlanır.
- **Denemeler:** Resmî cevap kâğıdı düzeninde giriş, net gelişim grafiği, ders bazlı performans, zayıf konular.
- **Notlar:**
  - Otomatik kayıt, renkler, sabitleme, yapılacaklar listesi.
  - İsteğe bağlı ders etiketi.
  - Arşiv ve 30 günlük çöp kutusu; sürükle-bırak ile sıralama, ızgara / liste görünümü.
- **Ajanda:** Takvim üzerinde planlar; istenirse Google Takvim'e gönderilir.
- **Hesap:** Google ile giriş, Firestore ile buluta senkronizasyon (çevrimdışı önce cihaza kaydeder),
  açık / koyu tema.

## Teknolojiler

Flutter 3.47 · Dart 3.13 · provider · Firebase Auth + Cloud Firestore · Google Sign-In ·
Google Calendar API · flutter_local_notifications · fl_chart · table_calendar

Android birincil platformdur. iOS yapılandırması tamamlanmadı. Web ve Windows yalnızca yerel modda (giriş ve
bildirim olmadan) çalışır.

## Kurulum

Firebase yapılandırma dosyaları depoda **yer almaz**. Uygulamayı çalıştırmak için kendi Firebase projenizi bağlayın.

1. [Flutter](https://docs.flutter.dev/get-started/install) kurun, ardından bağımlılıkları yükleyin:
   ```
   flutter pub get
   ```
2. [Firebase konsolunda](https://console.firebase.google.com) bir proje oluşturun:
   - **Authentication → Google** girişini açın.
   - **Firestore** veritabanı oluşturun.
   - Google Takvim özelliği için Google Cloud'da **Google Calendar API**'yi etkinleştirin.
3. FlutterFire CLI ile projeyi bağlayın. Bu adım `lib/firebase_options.dart`, `android/app/google-services.json`
   ve `firebase.json` dosyalarını üretir:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
4. Android'de Google girişi için imza anahtarınızın SHA-1 / SHA-256 parmak izlerini Firebase'deki Android
   uygulamasına ekleyin (`cd android && ./gradlew signingReport`).
5. Güvenlik kurallarını ve indeks ayarını yayınlayın. Kurallara göre her kullanıcı yalnızca `users/{uid}` altındaki
   kendi verisine erişebilir. `firestore.indexes.json` not alanlarını otomatik indekslemeden çıkarır (uygulama notlarda
   sunucu sorgusu yapmaz), bu da depolamayı azaltır. `firebase.json` içinde `"indexes": "firestore.indexes.json"`
   satırı olmalı:
   ```
   firebase deploy --only firestore:rules,firestore:indexes
   ```
6. Çalıştırın:
   ```
   flutter run
   ```

## Testler

```
flutter analyze
flutter test
```

## Proje yapısı

```
lib/
  core/        tema, müfredat verisi, servisler (auth, bulut, bildirim, takvim), ortak widget'lar
  models/      konu, oturum, deneme, not, ajanda, profil
  providers/   AppProvider: tek merkezi durum + yerel kayıt + bulut senkronizasyonu
  features/    dashboard, pomodoro, curriculum, exams, notes, agenda, onboarding, profile, home
```

## Not

Sınav tarihleri ve konu dağılımı ÖSYM'nin yayımladığı belgelere göre işlenmiştir. Resmî bilgi için her zaman
[ÖSYM](https://www.osym.gov.tr)'yi esas alın.
