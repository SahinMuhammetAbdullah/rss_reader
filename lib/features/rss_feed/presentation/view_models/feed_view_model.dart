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
  List<FeedItem> get feeds =>
      _feeds; // Ham veri, filtreleme/sıralama için kullanılmaz

  List<Category> _categories = [];
  List<Category> get categories => _categories;

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

  FeedViewModel({required this.repository});

  // =========================================================
  // Filtreleme ve Sıralama Mantığı
  // =========================================================

  List<FeedItem> get filteredAndSortedFeeds {
    // Kategoriye göre filtreleme
    List<FeedItem> filtered = [];

    if (_activeCategoryFilter == 'Hepsi') {
      filtered = List.from(_feeds); // Tüm beslemeleri al
    } else {
      // Aktif kategoriye göre filtrele
      final selectedCategory = _categories.firstWhere(
        (cat) => cat.name == _activeCategoryFilter,
        orElse: () => Category(
            id: -1, name: '', count: 0, icon: LucideIcons.folder, feedIds: []),
      );

      if (selectedCategory.id != -1) {
        // Seçilen kategoriye ait feed_id'leri içeren öğeleri filtrele
        filtered = _feeds.where((feed) {
          // Doğrudan feed.feedId alanını kullanıyoruz
          return selectedCategory.feedIds.contains(feed.feedId);
        }).toList();
      }
    }

    // Sıralama (Yayın Tarihine Göre)
    filtered.sort((a, b) {
      final int comparison = a.timestamp.compareTo(b.timestamp);
      return _sortOrder == 'desc' ? -comparison : comparison;
    });

    return filtered;
  }

  // ... (Diğer metodlar aynı kalır) ...

  Future<void> fetchAllRssData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // KRİTİK: Kategoriler feed'lerden önce çekilmeli
      await fetchCategories();
      await fetchFeeds();
    } catch (e) {
      _errorMessage = "Veri çekilirken hata oluştu: ${e.toString()}";
      print('Veri çekme hatası: $_errorMessage'); // Hata ayıklama için
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
        await fetchAllRssData(); // Giriş başarılıysa tüm verileri çek
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().contains('yanlış')
          ? e.toString()
          : "Giriş hatası: ${e.toString()}";
      print('Giriş hatası: $_errorMessage'); // Hata ayıklama için
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
      print('Feed çekme hatası: $_errorMessage'); // Hata ayıklama için
    }
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await repository.fetchCategories();
    } catch (e) {
      _errorMessage = "Kategoriler çekilemedi: ${e.toString()}";
      print('Kategori çekme hatası: $_errorMessage'); // Hata ayıklama için
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
      notifyListeners(); // Filtre değiştiğinde UI'yı güncelle
    }
  }

  void setSortOrder(String order) {
    if (_sortOrder != order) {
      _sortOrder = order;
      notifyListeners(); // Sıralama değiştiğinde UI'yı güncelle
    }
  }

  Future<bool> checkLoginStatus() async {
    return await repository.isUserLoggedIn();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await repository.logout();

    _feeds = [];
    _categories = [];
    _activeTab = 'home';
    _activeCategoryFilter = 'Hepsi'; // Logout'ta filtreyi sıfırla
    _sortOrder = 'desc'; // Logout'ta sıralamayı sıfırla

    _isLoading = false;
    notifyListeners(); // Listener tetiklenir ve FreshRSSMobileDesign logout'u algılar
  }
}
