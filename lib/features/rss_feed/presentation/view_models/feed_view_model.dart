// lib/features/rss_feed/presentation/view_models/feed_view_model.dart

import 'package:flutter/material.dart';
import 'package:fresh_rss_mobile_design/features/rss_feed/data/repositories/feed_repository.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../domain/models/feed_item.dart';

class FeedViewModel extends ChangeNotifier {
  final FeedRepository repository;

  // Durumlar
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String get errorMessage => _errorMessage ?? 'Bilinmeyen Hata';

  String _activeTab = 'home';
  String get activeTab => _activeTab;

  // Veri Listeleri
  List<FeedItem> _feeds = [];
  List<FeedItem> get feeds => _feeds; // Login kontrolü için gerekli

  List<RssCategory> _categories = [];
  List<RssCategory> get categories => _categories;

  // Simülasyon Verisi (ServersPage için zorunlu)
  final List<Server> _servers = [
    Server(
        name: "Fresh Flow Sunucusu",
        url: "rssreader.masahin.dev",
        status: "online",
        feeds: 42),
  ];
  List<Server> get servers => _servers;

  // Filtreleme ve Sıralama Durumu
  String _activeCategoryFilter = 'Hepsi';
  String get activeCategoryFilter => _activeCategoryFilter;

  String _sortOrder = 'desc'; // 'desc' (En yeni) veya 'asc' (En eski)
  String get sortOrder => _sortOrder;

  String _readFilter = 'all'; // 'all', 'unread', 'read'
  String get readFilter => _readFilter;

  String? _loggedInServerUrl;
  String? get loggedInServerUrl => _loggedInServerUrl;

  FeedViewModel(this.repository);
  // =========================================================
  // Filtreleme ve Sıralama Mantığı
  // =========================================================

  List<FeedItem> get filteredAndSortedFeeds {
    // 1. Kategori Filtreleme
    List<FeedItem> result = _feeds.where((feed) {
      if (_activeCategoryFilter == 'Hepsi') {
        return true;
      }

      final selectedCategory = _categories.firstWhere(
        (cat) => cat.name == _activeCategoryFilter,
        orElse: () => RssCategory(
            id: 0, name: '', count: 0, icon: LucideIcons.folder, feedIds: []),
      );

      final feedId = feed.feedId; // FeedItem modelindeki feedId kullanılır.

      if (feedId == 0) return false;

      // Seçili kategorinin feedIds listesinde bu feed ID'si var mı kontrol et
      return selectedCategory.feedIds.contains(feedId);
    }).toList();

    // 2. Okunmuş/Okunmamış Filtrelemesi
    result = result.where((feed) {
      if (_readFilter == 'unread') {
        return feed.unread;
      }
      if (_readFilter == 'read') {
        return !feed.unread;
      }
      return true; // 'all'
    }).toList();

    // 3. Sıralama (Yayın Tarihine Göre Kesin Sıralama)
    result.sort((a, b) {
      final order = a.timestamp.compareTo(b.timestamp);
      return _sortOrder == 'desc' ? -order : order;
    });

    return result;
  }

  // =========================================================
  // API ve Durum Yönetimi
  // =========================================================

  Future<void> fetchAllRssData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Kategori çekimi feed çekiminden önce olmalı ki eşleşme yapılabilsin
      await fetchCategories();
      await fetchFeeds();
    } catch (e) {
      _errorMessage = "Veri çekilirken hata oluştu: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String url, String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await repository.login(
          url: url, username: username, password: password);

      if (success) {
        _loggedInServerUrl = url;
        await fetchAllRssData();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().contains('yanlış')
          ? e.toString()
          : "Giriş hatası: ${e.toString()}";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFeeds() async {
    try {
      _feeds = await repository.fetchFeeds();
    } catch (e) {
      _errorMessage = "Akış verileri çekilemedi: ${e.toString()}";
    }
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await repository.fetchCategories();
    } catch (e) {
      _errorMessage = "Kategoriler çekilemedi: ${e.toString()}";
    }
  }

  Future<void> markItemStatus(String itemId, bool isRead) async {
    final index = _feeds.indexWhere((feed) => feed.id == itemId);

    // 1. YEREL GÜNCELLEME (Hata olsa da ikon değişsin)
    if (index != -1) {
      final currentFeed = _feeds[index];
      _feeds[index] = FeedItem(
        id: currentFeed.id,
        title: currentFeed.title,
        source: currentFeed.source,
        time: currentFeed.time,
        unread: !isRead, // Durumu yerel olarak tersine çevir
        image: currentFeed.image,
        category: currentFeed.category,
        url: currentFeed.url,
        timestamp: currentFeed.timestamp,
        feedId: currentFeed.feedId,
        // 🚨 KRİTİK: EKSİK OLAN ALANLAR EKLENDİ
      );
      notifyListeners();
    }

    // 2. SUNUCU İŞLEMİ VE KALICILIK

    try {
      await repository.markItemStatus(itemId, isRead);
      print('✅ Sunucuya güncelleme isteği başarıyla gönderildi.');

      // SUNUCU BAŞARILIYSA: Hata olmaması için zorunlu senkronizasyon
      await fetchAllRssData();
      print('🔄 Senkronizasyon başarılı, veri güncel.');
    } catch (e) {
      print('⚠️ Sunucuya kaydetme isteği gönderildi, ancak hata alındı. $e');
      // Hata durumunda kullanıcıya hata mesajını gösterme
      _errorMessage = 'Makale durumu sunucuya kaydedilemedi: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    _isLoading = true;
    notifyListeners();

    try {
      await repository.markAllAsRead();

      // KRİTİK DÜZELTME: Yerel listeyi güncelle ve tüm zorunlu parametreleri kopyala
      _feeds = _feeds
          .map<FeedItem>((feed) => FeedItem(
                // <<< TİP GÜVENLİĞİ: <FeedItem> ekle

                // ❌ Hata 1 Çözümü: Eksik olan zorunlu 'id' parametresi
                id: feed.id,

                title: feed.title,
                source: feed.source,
                time: feed.time,
                unread: false, // <<< Durumu okunmuş yap
                image: feed.image,
                category: feed.category,
                url: feed.url,
                timestamp: feed.timestamp,
                feedId: feed.feedId,
              ))
          .toList(); // <<< Hata 2 Çözümü: toList() tipi doğru döndürür

      _activeCategoryFilter = 'Hepsi'; // Filtreyi sıfırla
    } catch (e) {
      _errorMessage = 'Tümünü okundu işaretleme başarısız: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================
  // UI Aksiyonları
  // =========================================================

  void setActiveTab(String tabName) {
    if (_activeTab != tabName) {
      _activeTab = tabName;
      notifyListeners();
    }
  }

  void setActiveCategoryFilter(String categoryName) {
    if (_activeCategoryFilter != categoryName) {
      _activeCategoryFilter = categoryName;
      notifyListeners();
    }
  }

  void setSortOrder(String order) {
    if (_sortOrder != order) {
      _sortOrder = order;
      notifyListeners();
    }
  }

  void setReadFilter(String filter) {
    if (_readFilter != filter) {
      _readFilter = filter;
      notifyListeners();
    }
  }

  Future<bool> checkLoginStatus() async {
    final isLoggedIn = await repository.isUserLoggedIn();
    if (isLoggedIn) {
      _loggedInServerUrl = await repository.getServerUrl();
    }
    return isLoggedIn;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await repository.logout();

    // Tüm durumları sıfırla
    _feeds = [];
    _categories = [];
    _activeTab = 'home';
    _activeCategoryFilter = 'Hepsi';
    _sortOrder = 'desc';
    _readFilter = 'all';
    _loggedInServerUrl = null;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSubscription(String url) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Repository'den kimlik bilgilerini çek (API çağrısı için zorunlu)
      final credentials = await repository.getCredentials();

      final token = credentials['authToken'];
      final apiUrl = credentials['url'];

      if (token == null || apiUrl == null) {
        // Eğer token veya URL eksikse (kullanıcı logout olmuşsa)
        throw Exception(
            "Yetkilendirme bilgileri eksik. Lütfen yeniden giriş yapın.");
      }

      // Repository üzerinden quickadd API çağrısını başlat
      // NOT: Repository'nin bu metodu çağırmadan önce API'ye uygun formatta olduğundan emin olun.
      await repository.addSubscription(apiUrl, token, url);
      _errorMessage = null; // Başarılıysa hata mesajını temizle
    } catch (e) {
      _errorMessage = "Abonelik eklenemedi: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners(); // UI'ı güncelle
    }
  }

  List<FeedSubscription> getFeedsForCategory(int categoryId) {
    // 1. targetCategory artık RssCategory? tipindedir.
    final targetCategory =
        categories.firstWhereOrNull((cat) => cat.id == categoryId);

    // 2. Eğer kategori bulunamazsa, boş liste dön.
    if (targetCategory == null) return [];

    return targetCategory.feedIds.map((feedId) {
      final feedTitle = 'Feed Adı: $feedId';

      return FeedSubscription(
        feedId: feedId,
        title: feedTitle,
        categoryName: targetCategory.name, // targetCategory null değil
        categoryId: categoryId,
      );
    }).toList();
  }

  Future<void> removeSubscription(int feedId) async {
    // ... (Loading state, credentials check) ...
    try {
      final credentials = await repository.getCredentials();
      final apiUrl = credentials['url']!;
      final token = credentials['authToken']!;
      await repository.unsubscribeFeed(apiUrl, token, feedId);
      await fetchAllRssData(); // UI ve cache yenileme
    } catch (e) {
      // ... (Error handling) ...
    } finally {
      // ...
    }
  }

  Future<void> moveSubscription(int feedId, String newCategoryName,
      {required String oldCategoryName}) async {
    // ... (Loading state, credentials check) ...
    try {
      final credentials = await repository.getCredentials();
      final apiUrl = credentials['url']!;
      final token = credentials['authToken']!;

      // Artık ViewModel'den değil, Repository'den çekilen bilgileri kullan
      await repository.setFeedCategory(apiUrl, token, feedId, newCategoryName,
          oldCategoryName: oldCategoryName);
    } catch (e) {
      // ... (Error handling) ...
    } finally {
      // ...
    }
  }
}

extension RssCategoryListExtension on List<RssCategory> {
  // Bu uzantı, bir öğe bulunamazsa null döndürür
  RssCategory? firstWhereOrNull(bool Function(RssCategory) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
