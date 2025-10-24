# rss_reader

A new Flutter project.


lib/
├── core/
│   ├── constants/
│   │   └── app_colors.dart         // Renkler
│   ├── theme/
│   │   └── app_theme.dart          // Tema (Material/Text stilleri)
├── features/
│   └── rss_feed/                     // Özelliğe Özel Dizin
│       ├── presentation/
│       │   ├── pages/
│       │   │   ├── fresh_rss_app.dart    // Ana uygulama (MaterialApp)
│       │   │   ├── login_page.dart       // Giriş Sayfası
│       │   │   └── feed_page.dart        // Akış Sayfası
│       │   ├── widgets/
│       │   │   ├── feed_item_card.dart
│       │   │   └── bottom_nav_bar.dart
│       │   └── view_models/
│       │       └── feed_view_model.dart  // State yönetimi (ChangeNotifier, vb.)
│       ├── domain/
│       │   └── models/
│       │       ├── feed_item.dart        // Veri Modelleri
│       │       └── category.dart
│       └── data/
│           ├── repositories/
│           │   └── feed_repository.dart  // Veri çekme/işleme
│           └── datasources/
│               └── static_data.dart      // Statik Veri Kaynağı
├── l10n/
│   └── app_tr.arb                    // Lokalizasyon (Şimdilik atlıyoruz)
└── main.dart                       // Başlangıç dosyası