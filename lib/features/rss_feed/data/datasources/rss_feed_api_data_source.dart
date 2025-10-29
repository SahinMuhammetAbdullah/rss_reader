// lib/features/rss_feed/data/datasources/rss_feed_api_data_source.dart

import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

// FeedItem ve Category modellerini içerir.
// (Kullanıcının model dosyasına göre Category yerine RssCategory de olabilir.)
import '../../domain/models/feed_item.dart';

final Dio _httpClient = Dio();

// =================================================================
// YARDIMCI FONKSİYONLAR
// =================================================================

void _setupHttpClientForDev() {
  if (kDebugMode && (Platform.isAndroid || Platform.isIOS)) {
    _httpClient.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // Geliştirme ortamında SSL sertifika hatalarını yok say
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
    if (kDebugMode) print('✅ DEV Ortamı: SSL sertifika doğrulaması ATLANDI.');
  }
}

String _formatTimeAgo(int timestamp) {
  final now = DateTime.now();
  final publishedDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  final difference = now.difference(publishedDate);

  if (difference.inDays > 7) {
    return '${publishedDate.day}.${publishedDate.month}.${publishedDate.year}';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} gün önce';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} saat önce';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} dk önce';
  } else {
    return 'Şimdi';
  }
}

// =================================================================
// ABSTRACT SINIF TANIMI
// =================================================================
abstract class RssFeedDataSource {
  Future<String> authenticate(String url, String username, String password);
  Future<List<RssCategory>> getCategories(
      String apiUrl, String token); // <<< TİP DÜZELTİLDİ
  Future<List<FeedItem>> getFeedItems(String apiUrl, String token);
}

// =================================================================
// SOMUT SINIF UYGULAMASI (Google Reader API Uyumlu)
// =================================================================
class RssFeedApiDataSource implements RssFeedDataSource {
  // Veri Cache'leri
  List<RssCategory> _categoriesCache = [];
  Map<int, int> _feedIdToGroupId = {}; // Feed ID -> Category ID eşleştirme
  Map<int, String> _feedIdToFeedName =
      {}; // Feed ID -> Feed Adı (Source Name) eşleştirme

  RssFeedApiDataSource() {
    _setupHttpClientForDev();
  }

  String _normalizeUrl(String url) {
    String normalizedUrl = url.replaceAll(RegExp(r'/+$'), '');
    if (!normalizedUrl.startsWith('https://') &&
        !normalizedUrl.startsWith('http://')) {
      normalizedUrl = 'https://' + normalizedUrl;
    }
    normalizedUrl = normalizedUrl.replaceFirst('http://', 'https://');
    return normalizedUrl;
  }

  // ===============================================================
  // 🔐 1. Kimlik Doğrulama (GRAPI: ClientLogin)
  // ===============================================================
  @override
  Future<String> authenticate(
      String url, String username, String password) async {
    final normalizedUrl = _normalizeUrl(url);
    // Dökümantasyonda belirtilen ClientLogin uç noktası
    final authEndpointUrl =
        '$normalizedUrl/p/api/greader.php/accounts/ClientLogin';

    try {
      final response = await _httpClient.post(
        authEndpointUrl,
        data: {
          'Email': username,
          'Passwd': password,
          'accountType': 'HOSTED_OR_GOOGLE',
          'service': 'reader',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // 401 hatalarını yakalamak için validateStatus ayarı
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 400 || status == 401),
        ),
      );

      if (response.statusCode == 200 && response.data is String) {
        final String responseBody = response.data.toString();

        final tokenMatch = RegExp(r'Auth=(.+)\n?').firstMatch(responseBody);
        if (tokenMatch != null && tokenMatch.group(1) != null) {
          // Token: "alice/8e6845e0..." formatında döndürülür
          return tokenMatch.group(1)!;
        } else {
          throw Exception('❌ GRAPI yanıtında Auth token bulunamadı.');
        }
      } else if (response.statusCode == 401) {
        throw Exception(
            '❌ Yetkilendirme Başarısız! Kullanıcı adı veya şifre hatalı.');
      } else {
        throw Exception(
            '❌ Kimlik doğrulama geçersiz yanıt: ${response.statusCode} - ${response.data}');
      }
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('⚠️ Beklenmeyen hata (Kimlik Doğrulama): $e');
    }
  }

  // ===============================================================
  // 📂 2. Kategorileri Getir (GRAPI: tag/list + subscription/list)
  // ===============================================================
  @override
  Future<List<RssCategory>> getCategories(String apiUrl, String token) async {
    final normalizedUrl = _normalizeUrl(apiUrl);
    // Dökümantasyonda belirtilen uç noktalar
    final tagsEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/tag/list?output=json';
    final subscriptionsEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/subscription/list?output=json';

    try {
      // ÇALIŞAN GRAPI HEADER FORMATI: Authorization: GoogleLogin auth=TOKEN
      final headers = {'Authorization': 'GoogleLogin auth=$token'};

      final tagsResponse = await _httpClient.get(tagsEndpointUrl,
          options: Options(headers: headers));
      final subscriptionsResponse = await _httpClient
          .get(subscriptionsEndpointUrl, options: Options(headers: headers));

      if (tagsResponse.statusCode == 200 &&
          subscriptionsResponse.statusCode == 200) {
        final tagsJson = tagsResponse.data['tags'] as List? ?? [];
        final subscriptionsJson =
            subscriptionsResponse.data['subscriptions'] as List? ?? [];

        // Önbellekleri temizle
        _feedIdToFeedName.clear();
        _feedIdToGroupId.clear();

        // --- 2a: Feed/Grup Eşleştirmesi ve Feed Adı Cache'i ---
        for (var sub in subscriptionsJson) {
          final String feedIdStr = sub['id'] as String? ?? '';
          final String feedTitle =
              sub['title'] as String? ?? 'Bilinmeyen Kaynak';
          final int feedId = feedIdStr
              .hashCode; // FreshRSS'in ID'si URI olduğundan hash kullanılır

          _feedIdToFeedName[feedId] = feedTitle; // Feed Adını Kaydet

          final List categoriesOfFeed = sub['categories'] as List? ?? [];
          for (var categoryEntry in categoriesOfFeed) {
            final String tagId = categoryEntry['id'] as String? ?? '';
            final String categoryName = tagId.split('/').lastWhere(
                (element) => element.isNotEmpty,
                orElse: () => 'Genel');
            final int categoryId = categoryName.hashCode;
            _feedIdToGroupId[feedId] = categoryId;
          }
        }

        // --- 2b: Grup Adları, Sayıları ve Listesi ---
        Map<int, List<int>> groupFeeds = {};
        Map<int, int> groupFeedCount = {};
        Map<int, String> groupIdToName = {};

        // Tags'lardan kategori adlarını ve ID'lerini al
        for (var tag in tagsJson) {
          final String tagId = tag['id'] as String? ?? '';
          final String tagName = tagId.split('/').lastWhere(
              (element) => element.isNotEmpty,
              orElse: () => 'Genel');
          final int categoryId = tagName.hashCode;

          groupIdToName[categoryId] = tagName;
          groupFeeds[categoryId] = [];
          groupFeedCount[categoryId] = 0;
        }

        // Genel (Untagged) feed'leri işle
        _feedIdToFeedName.keys.forEach((feedId) {
          final int groupId = _feedIdToGroupId[feedId] ?? 'Genel'.hashCode;
          if (!groupIdToName.containsKey(groupId)) {
            groupIdToName[groupId] = 'Genel';
            groupFeeds[groupId] = [];
            groupFeedCount[groupId] = 0;
            _feedIdToGroupId[feedId] = groupId;
          }
          groupFeeds[groupId]!.add(feedId);
          groupFeedCount[groupId] = (groupFeedCount[groupId] ?? 0) + 1;
        });

        // --- 2c: Category Listesi Oluşturma ---
        _categoriesCache = groupIdToName.entries.map((entry) {
          final int groupId = entry.key;
          final String groupName = entry.value;
          final int feedCount = groupFeedCount[groupId] ?? 0;

          return RssCategory(
            id: groupId,
            name: groupName,
            count: feedCount,
            icon: LucideIcons.folder,
            feedIds: groupFeeds[groupId] ?? [],
          );
        }).toList();

        // "Hepsi" Kategorisini Ekle
        List<int> allFeedIds = _feedIdToFeedName.keys.toList();
        int totalFeedCount = allFeedIds.length;
        _categoriesCache.insert(
          0,
          RssCategory(
            name: "Hepsi",
            count: totalFeedCount,
            icon: LucideIcons.home,
            id: 0,
            feedIds: allFeedIds,
          ),
        );

        return _categoriesCache;
      } else {
        throw Exception(
            '❌ Kategoriler alınamadı: GRAPI sunucu durumu kodu: Tags: ${tagsResponse.statusCode}, Subscriptions: ${subscriptionsResponse.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        throw Exception(
            '⚠️ Bağlantı Hatası: Sunucuya erişilemiyor. ${e.message}');
      }
      // Hata Yönetimi: Bu blok, 501/Yönlendirme döngüsü hatalarını yakalar
      throw Exception('⚠️ Dio Hatası oluştu (Kategoriler): ${e.message}');
    } catch (e) {
      throw Exception('⚠️ Beklenmeyen hata (Kategoriler): $e');
    }
  }

  // ===============================================================
  // 📰 3. RSS Feed Ögelerini Getir (GRAPI: stream/contents)
  // ===============================================================
  @override
  Future<List<FeedItem>> getFeedItems(String apiUrl, String token) async {
    final normalizedUrl = _normalizeUrl(apiUrl);
    // Dökümantasyonda belirtilen uç nokta: reading-list tüm feed'leri çeker
    final streamEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list?output=json';

    try {
      final response = await _httpClient.get(
        streamEndpointUrl,
        queryParameters: {
          'n': 200, // Çekilecek öğe sayısı
          'r': 'd', // azalan sıralama (en yeni en üstte)
        },
        options: Options(
          headers: {
            'Authorization': 'GoogleLogin auth=$token'
          }, // Düzeltilmiş Header
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;
        final itemsJson = json['items'] as List? ?? [];
        List<FeedItem> feedItems = [];

        for (var item in itemsJson) {
          final String itemId = item['id'] as String? ?? '';
          final String title = item['title'] as String? ?? 'Başlıksız';
          final int timestamp = (item['published'] as int? ?? 0);
          final String itemUrl = item['alternate'] != null &&
                  (item['alternate'] as List).isNotEmpty
              ? (item['alternate'] as List).first['href'] as String? ?? '#'
              : '#';
          final List categories = item['categories'] as List? ?? [];
          final bool isRead =
              categories.contains('user/-/state/com.google/read');

          // FreshRSS/GRAPI, feed ID'yi origin/streamId olarak verir (URI formatında)
          final String feedIdStr = item['origin']?['streamId'] as String? ?? '';
          final int feedId = feedIdStr.hashCode;

          // 🚀 Kaynak Adını Cache'den çekme
          final String sourceName = _feedIdToFeedName[feedId] ??
              item['origin']?['title'] as String? ??
              'Bilinmeyen Kaynak';

          // Kategori Adını Eşleştirme
          String categoryName = 'Genel';
          int groupId = 'Genel'.hashCode;
          if (_feedIdToGroupId.containsKey(feedId)) {
            groupId = _feedIdToGroupId[feedId]!;
            final RssCategory? categoryInCache =
                _categoriesCache.firstWhereOrNull((cat) => cat.id == groupId);
            categoryName = categoryInCache?.name ?? 'Genel';
          }

          feedItems.add(
            FeedItem(
              id: itemId.hashCode,
              title: title,
              source: sourceName, // Kaynak Adı
              feedId: feedId, // Filtreleme için ID
              time: _formatTimeAgo(timestamp),
              unread: !isRead,
              category: categoryName,
              url: itemUrl,
              timestamp: timestamp, sourceName: sourceName,
            ),
          );
        }
        return feedItems;
      } else {
        throw Exception(
            '❌ Feed öğeleri alınamadı: GRAPI sunucu durumu kodu: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        throw Exception(
            '⚠️ Bağlantı Hatası: Sunucuya erişilemiyor. ${e.message}');
      }
      // Hata Yönetimi: Yönlendirme döngüsü/sunucu hatalarını yakalar
      throw Exception('⚠️ Dio Hatası oluştu (Feed Öğeleri): ${e.message}');
    } catch (e) {
      throw Exception('⚠️ Beklenmeyen hata (Feed Öğeleri): $e');
    }
  }

  // Eksik Dio Helper'ı Ekle
  void _setupDioInterceptors() {
    /* ... */
  } // Daha önce eklediğiniz interceptor metodu buraya gelmeli.
}

// firstWhereOrNull uzantısını simüle edelim (eğer projenizde yoksa)
extension on List<RssCategory> {
  RssCategory? firstWhereOrNull(bool Function(RssCategory) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
