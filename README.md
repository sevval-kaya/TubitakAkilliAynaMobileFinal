# TubitakAkilliAynaMobileFinal

TUBITAK 2209-A - Yapay Zeka Destekli Akilli Ayna
Flutter Android Mobil Uygulama | Hugging Face AI Entegrasyonu

Danisman: Doc. Dr. Sinem Akyol
Koordinator: Sevval Kaya
Gelistirici: Berkay Parcal
Gelistirici: Esra Kazan

---

# Ekran Goruntuleri

### Uygulama Ekranlari

| Izin Ekrani | Hosgeldin | Profil Olustur |
|-------------|-----------|---------------|
| ![Izin](screenshots/izin.jpg) | ![Hosgeldin](screenshots/hosgeldin.jpg) | ![Profil Olustur](screenshots/profil_olustur.jpg) |

| Profil Olustur (Rol) | Ana Ekran | Gorevler |
|---------------------|-----------|----------|
| ![Profil Rol](screenshots/profil_olustur_rol.jpg) | ![Ana Ekran](screenshots/anaekran.jpeg) | ![Gorevler](screenshots/gorev.jpg) |

| Profil |
|--------|
| ![Profil](screenshots/profil.jpg) |

---

# Proje Nedir?

Bu uygulama, TUBITAK 2209-A kapsaminda gelistirilen yapay zeka destekli akilli ayna projesinin Android mobil uygulamasidir. Kullanici sesli komutlarla gundelik gorevlerini yonetebilir, yapay zeka asistaniyla konusabilir.

Yapay zeka modeli Hugging Face uzerinde barindirılmaktadir. Yerel bir sunucu kurmaniza gerek yoktur, internet baglantisi yeterlidir.

---

# Nasil Calisir?

```
Kullanici mikrofon butonuna basar ve konusur
      |
Uygulama sesi metne cevirir (speech-to-text, Turkce)
      |
Metin ve gorev listesi Hugging Face API'ye gonderilir
      |
Fine-tuned Qwen2.5-3B modeli yanit uretir
      |
Yanit sesli olarak okunur (text-to-speech, Turkce)
```

---

# Ozellikler

- Sesli komutla gorev sorgulama (bugun ne var, yarin programim ne vb.)
- Sesle gorev ekleme (gorev ekle, hatirla, not al vb.)
- Coklu kullanici destegi (PIN korumali profiller)
- Zaman dilimi algisi (sabah, ogleden sonra, aksam)
- Conversation history (son 5 tur hatirlama)
- Hallusinasyon engelleme (gorev yoksa model uydurma yapmaz)
- Hugging Face API entegrasyonu (yerel sunucu gerekmez)

---

# Kullanilan Teknolojiler

| Katman | Teknoloji |
|--------|-----------|
| Mobil Framework | Flutter (Android) |
| State Management | BLoC / Cubit |
| AI Modeli | Qwen2.5-3B-Instruct (QLoRA fine-tuned) |
| Model Barindirilmasi | Hugging Face Inference API |
| Ses Tanima | speech_to_text (tr_TR) |
| Ses Sentezi | flutter_tts (tr-TR) |
| Veritabani | SQLite (sqflite) |
| Guvenlik | SHA-256 PIN, flutter_secure_storage |
| HTTP | Dio |
| DI | GetIt |

---

# Kurulum

## 1. Depoyu Indirin

```bash
git clone https://github.com/RudblestThe2nd/TubitakAkilliAynaMobileFinal.git
cd TubitakAkilliAynaMobileFinal
```

## 2. Bagimliliklari Yukleyin

```bash
flutter pub get
```

## 3. HF API Token Ayarini Yapin

lib/core/constants/api_constants.dart dosyasini acin:

```dart
static const String hfToken = 'hf_SIZIN_TOKENINIZ';
static const String hfModel = 'Rudblest/AkilliAyna-Qwen3B';
```

HuggingFace token almak icin: https://huggingface.co/settings/tokens

## 4. Uygulamayi Telefona Yukleyin

Telefonu USB ile baglayin, USB Hata Ayiklama acik olmalidir.

```bash
flutter run
```

---

# Uygulamayi Kullanmak

Uygulama ilk acildiginda izin ekrani gorulur. Onaylayip devam edin.

Profil olusturun: isim, PIN ve rol secin. Birden fazla aile uyesi farkli profil olusturabilir.

Gorev eklemek icin alt menudeki Gorevler sekmesinden + butonuna basin.

Sesli asistan icin ana sayfadaki mikrofon butonuna basin ve konusun.

Ornek sesli komutlar:
- "Bugun ne yapacagim"
- "Yarin programim ne"
- "Bu hafta ne var"
- "Sabah planim nedir"
- "Gorev ekle yarin saat 10 toplanti"
- "Hatirla aksam ilac al"

---

# Sistem Izleme (Prometheus + Grafana)

> Bu bolum model yuklendikten sonra doldurulacaktir.

Backend Prometheus metrikleri ve Grafana dashboard goruntuleri buraya eklenecektir.

---

# Veri Analizi (SPSS / R / Python)

> Bu bolum analiz tamamlandiktan sonra doldurulacaktir.

SQLite veritabanindan uretilen istatistik grafikleri buraya eklenecektir.

| Genel Bakis | Tamamlanma Analizi | Zaman Analizi |
|-------------|-------------------|---------------|
| ![ Genel Bakis](screenshots/grafik1_genel_bakis.png) | ![Tamamlanma](screenshots/grafik2_tamamlanma_analizi.png) | ![Zaman](screenshots/grafik3_zaman_analizi.png) |

---

# Sik Sorulan Sorular

AI yanit vermiyor:
HF token'inin dogru girildiginden emin olun. Token okuma iznine sahip olmalidir.

Yanit cok yavas geliyor:
HF Inference API ucretsiz planda soguk baslangic yasanabilir. Ilk istek 30-60 saniye surebilir, sonrakiler daha hizli olur.

Uygulama telefona yuklenmiyor:
USB Hata Ayiklama seceneginin acik oldugunu kontrol edin.

Yapay zeka yanlis cevap veriyor:
Once Gorevler sekmesinden gorev ekleyin, sonra sorun. Gorev olmadan model "planin bulunmuyor" der.

---

# Ana Repo (Backend + LLM)

Backend, fine-tuning scriptleri ve model egitimi icin ana repo:
https://github.com/RudblestThe2nd/AkilliAynaAsistanLLM

---

TUBITAK 2209-A - Firat Universitesi - 2025-2026

---

# Gelistirici Katkilari

## Sevval Kaya - Flutter Mobil Uygulama

Flutter uygulamasinin tamamini sifirdan gelistirdi:

- TaskBloc: gorev CRUD islemleri, filtreleme, tamamlama, arama
- UserCubit: coklu kullanici yonetimi, SHA-256 ile PIN hashleme, rol sistemi (Admin/Member/Guest)
- VoiceCubit: STT, AI ve TTS arasindaki akis yonetimi altyapisi
- SQLite veritabani: tasks ve users tablolari, migration destekli v2 yapisi
- Sayfalar: consent_page (izin ekrani), dashboard_page (ana panel), tasks_page (gorev listesi), profile_page (profil yonetimi)
- Widgetlar: task_card_widget (swipe-to-delete ile gorev karti), voice_assistant_widget (mikrofon + TTS durum)
- flutter_secure_storage ile Android Keystore / iOS Keychain sifreleme
- flutter_local_notifications ile gorev hatirlaticilari
- Noto Sans font ile tam Turkce karakter destegi, koyu tema, animate_do animasyonlari
- iOS ve Android destegi
- Gorev sesli okuma ozelligi (gorev karti uzerindeki buton)
- Swipe to delete + onay diyalogu
- Gunluk selamlama mesajlari (sabah / ogleden sonra / aksam)
- Fiziksel ayna kurulumu: Bluetooth mikrofon ve hoparlor montaji

---

## Berkay Parcal + Esra Kazan - LLM, Backend ve Uygulama Entegrasyonu

### Flutter Uygulamasina Eklenenler

- Dependency injection duzeltmesi: VoiceCubit'e TaskBloc inject edilmemesinden kaynaklanan crash sorunu giderildi (injection_container.dart: registerFactory -> registerFactoryParam)
- Ilk kurulum ekrani (first_setup_page.dart): hic profil yoksa animasyonlu hosgeldin ekrani, 2 adimli profil olusturma akisi (isim, PIN, rol secimi), otomatik dashboard yonlendirmesi
- Demo seed verisi: ilk kullanici olusturulunca _seedDemoTasks() ile 16 ornek gorev otomatik ekleniyor (10-17 Mart 2026 arasi)
- Context fix - akilli filtreleme (_buildTaskContext): "bugun", "yarin", "X Mart", "bu hafta" tarih algisi; "sabah" (06-12), "ogleden sonra" (12-18), "aksam" (18-22), "saat 14" gibi zaman dilimi algisi
- Sesle gorev ekleme (_tryAddTaskFromVoice): "gorev ekle", "hatirla", "not al", "yeni gorev", "listeye ekle" intent algisi; saat cikarimi (saat 14:30, sabah->09:00, ogle->12:00, aksam->19:00, gece->21:00); tarih cikarimi (yarin, 15 mart); onay mesaji ile TTS dogrulamasi
- Conversation history: son 5 tur (10 mesaj) RAM'de tutuluyor, her istekte backend'e gonderiliyor
- Hallusinasyon engelleme: has_no_tasks() kontrolu ile gorev olmayan tarihlerde model devreye girmeden "planin bulunmuyor" yaniti donduruluyor; temperature=0.1 ve repetition_penalty=1.2 ile deterministic yanit
- HF Dedicated Endpoint entegrasyonu: api_service.dart ve api_constants.dart HF API'ye donusturuldu, NGINX bagimliligı kaldirildi, Qwen prompt formati (system + history + GOREV LISTESI) eklendi
- Offline mod: baglanti yoksa kural tabanli yerel yanitlar (_buildOfflineResponse)

### LLM ve Backend

- Model secim sureci: LLaMA 1.5B -> Qwen2.5-1.5B -> Qwen2.5-3B degerlendirmesi
- QLoRA fine-tuning: 4-bit NF4 quantization, LoRA r=8/alpha=16, 7 hedef modul, 3350 Turkce ornek, 3 epoch, final loss ~0.13, ~1.5-2 saat (RTX 4060)
- Dataset revizyonu: 1521 yerde "March" -> "Mart" donusumu; "en yogun gun", "en az yogun gun", "bos saatler" sorulari duzeltildi; 300 sesle gorev ekleme ornegi ve 50 sohbet ornegi eklendi; Flutter'in {tasks:[...]} formatina uygun hale getirildi
- FastAPI backend (main.py): 3 endpoint (/status, /infer, /voice/process), conversation history, hallusinasyon engelleme, Prometheus metrikleri
- NGINX TLS proxy: port 8443 -> 8000, self-signed sertifika destegi
- Prometheus izleme: 5 custom metrik (voice_requests_total, ai_response_seconds, hallucination_blocked_total, model_ready, voice_task_added_total), /metrics endpoint
- Grafana dashboard: 8 panel (JSON dosyasi backend/ klasorunde)
- SQLite analiz scripti (analiz.py): 3 grafik + CSV ciktisi, demo veri destegi
- Model merge: LoRA adaptoru + base model birlestirildi (qwen3b-merged, 5.8GB)
- HF Dedicated Endpoint'e yukleme: Rudblest/AkilliAyna-Qwen3B
- GitHub repo yonetimi: README, ekran goruntuleri, surum etiketleri, repo temizleme
- TUBITAK raporu: Word (.docx) ve PDF formatinda (10 bolum)

---

TUBITAK 2209-A - Firat Universitesi - 2025-2026
