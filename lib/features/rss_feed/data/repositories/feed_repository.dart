// lib/features/rss_feed/data/repositories/feed_repository.dart (GÜNCEL)

import '../../../../core/services/secure_storage_service.dart';
import '../datasources/rss_feed_api_data_source.dart';
import '../../domain/models/feed_item.dart';

class FeedRepository {
  final RssFeedApiDataSource apiDataSource;
  final SecureStorageService storageService;

  FeedRepository({
    required this.apiDataSource,
    required this.storageService,
  });

  // Giriş İşlemi (Simülasyon kaldırıldı, Gerçek API çağrısı etkinleştirildi)
  Future<bool> login({
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      final token = await apiDataSource.authenticate(url, username, password);

      // KRİTİK DÜZELTME: Orijinal şifreyi de kaydet
      await storageService.saveCredentials(
          url: url,
          username: username,
          authToken: token,
          originalPassword: password // <<< EKLENDİ
          );
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FeedItem>> fetchFeeds() async {
    try {
      final credentials = await storageService.getCredentials();
      final url = credentials['url']!;
      final token = credentials['authToken']!;

      // Gerçek API çağrısı
      final apiFeeds = await apiDataSource.getFeedItems(url, token);
      return apiFeeds;
    } catch (e) {
      // Hata durumunda boş liste döndürerek uygulamanın çökmesini engelle
      print("⚠️ HATA: Feedler çekilemedi. Boş liste döndürülüyor. Detay: $e");
      return [];
    }
  }

  Future<List<RssCategory>> fetchCategories() async {
    try {
      final credentials = await storageService.getCredentials();
      final url = credentials['url']!;
      final token = credentials['authToken']!;

      // Gerçek API çağrısı
      return await apiDataSource.getCategories(url, token);
    } catch (e) {
      print(
          "⚠️ HATA: Kategoriler çekilemedi. Boş liste döndürülüyor. Detay: $e");
      return [];
    }
  }

  Future<String?> getServerUrl() async {
    return storageService.getServerUrl();
  }

  Future<void> markItemStatus(String itemId, bool isRead) async {
    // <<< SADECE İHTİYAÇ OLAN PARAMETRELER KALDI
    final credentials = await storageService.getCredentials();
    final url = credentials['url']!;
    final token = credentials['authToken']!;

    // DataSource'u çağır
    await apiDataSource.markItemStatus(
        url, token, itemId, isRead); // <<< 4 ARGÜMAN GÖNDERİLİYOR
  }

  Future<bool> isUserLoggedIn() => storageService.isUserLoggedIn();

  Future<void> logout() => storageService.logout();
  Future<void> markAllAsRead() async {
    final credentials = await storageService.getCredentials();
    final url = credentials['url']!;
    final token = credentials['authToken']!;

    await apiDataSource.markAllAsRead(url, token);
  }
}
