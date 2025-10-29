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
      // API'den token'ı al
      final token = await apiDataSource.authenticate(url, username, password);

      // Başarılı olursa, token'ı güvenli depoda sakla
      await storageService.saveCredentials(
          url: url, username: username, authToken: token);

      return true; // Giriş başarılı
    } catch (e) {
      rethrow; // ViewModel'e hatayı ilet
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

  Future<bool> isUserLoggedIn() => storageService.isUserLoggedIn();

  Future<void> logout() => storageService.logout();
}
