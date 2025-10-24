// lib/features/rss_feed/presentation/view_models/feed_view_model.dart

import 'package:flutter/material.dart';
import 'package:fresh_rss_mobile_design/features/rss_feed/data/repositories/feed_repository.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../domain/models/feed_item.dart';

class FeedViewModel extends ChangeNotifier {
  final FeedRepository repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String get errorMessage => _errorMessage ?? 'Bilinmeyen Hata';

  String _activeTab = 'home';
  String get activeTab => _activeTab;

  List<FeedItem> _feeds = [];
  List<FeedItem> get feeds => _feeds;

  List<RssCategory>  _categories = [];
  List<RssCategory>  get categories => _categories;

  final List<Server> _servers = [
    Server(
        name: "Fresh Flow Sunucusu",
        url: "rssreader.masahin.dev",
        status: "online",
        feeds: 42),
  ];
  List<Server> get servers => _servers;

  String _activeCategoryFilter = 'Hepsi';
  String get activeCategoryFilter => _activeCategoryFilter;

  String _sortOrder = 'desc';
  String get sortOrder => _sortOrder;

  FeedViewModel({required this.repository});

  List<FeedItem> get filteredAndSortedFeeds {
    List<FeedItem> filtered = [];

    if (_activeCategoryFilter == 'Hepsi') {
      filtered = List.from(_feeds);
    } else {
      final selectedCategory = _categories.firstWhere(
        (cat) => cat.name == _activeCategoryFilter,
        orElse: () => RssCategory(
            id: -1, name: '', count: 0, icon: LucideIcons.folder, feedIds: []),
      );

      if (selectedCategory.id != -1) {
        filtered = _feeds.where((feed) {
          return selectedCategory.feedIds.contains(feed.feedId);
        }).toList();
      }
    }

    filtered.sort((a, b) {
      final int comparison = a.timestamp.compareTo(b.timestamp);
      return _sortOrder == 'desc' ? -comparison : comparison;
    });

    return filtered;
  }

  Future<void> fetchAllRssData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await fetchCategories();
      await fetchFeeds();
    } catch (e) {
      _errorMessage = "Veri çekilirken hata oluştu: ${e.toString()}";
      print('Veri çekme hatası: $_errorMessage');
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
        await fetchAllRssData();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().contains('yanlış')
          ? e.toString()
          : "Giriş hatası: ${e.toString()}";
      print('Giriş hatası: $_errorMessage');
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
      print('Feed çekme hatası: $_errorMessage');
    }
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await repository.fetchCategories();
    } catch (e) {
      _errorMessage = "Kategoriler çekilemedi: ${e.toString()}";
      print('Kategori çekme hatası: $_errorMessage');
    }
  }

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
    _activeCategoryFilter = 'Hepsi';
    _sortOrder = 'desc';

    _isLoading = false;
    notifyListeners();
  }
}