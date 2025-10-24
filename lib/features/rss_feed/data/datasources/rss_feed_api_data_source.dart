// lib/features/rss_feed/data/datasources/rss_feed_api_data_source.dart

import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../domain/models/feed_item.dart';

final Dio _httpClient = Dio();

// Geçici SSL/Sertifika Doğrulamasını Atlar (DEV'de kalmalı)
void _setupHttpClientForDev() {
  if (Platform.isAndroid || Platform.isIOS) {
    _httpClient.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // ❌ Bu satır KALDIRILIYOR veya YORUM SATIRI yapılıyor:
        // client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
  }
  print('PROD: SSL sertifika doğrulaması DEVREDE.');
}

// Yardımcı Fonksiyon: Zaman damgasını "X önce" formatına çevirir
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
  Future<List<Category>> getCategories(String apiUrl, String token);
  Future<List<FeedItem>> getFeedItems(String apiUrl, String token);
}

// =================================================================
// SOMUT SINIF UYGULAMASI
// =================================================================
class RssFeedApiDataSource implements RssFeedDataSource {
  RssFeedApiDataSource() {
    _setupHttpClientForDev();
  }

  // Kategori Eşleştirme için Cache alanları
  List<Category> _categoriesCache = [];
  Map<int, int> _feedIdToGroupId = {}; // feed_id -> group_id eşlemesi
  // YENİ: feed_id -> feed_adı eşlemesi için bir cache
  Map<int, String> _feedIdToName = {};

  // ===============================================================
  // 🔐 1. Kimlik Doğrulama (Fever API)
  // ===============================================================
  @override
  Future<String> authenticate(
      String url, String username, String password) async {
    // URL normalleştirme
    String normalizedUrl = url.replaceAll(RegExp(r'/+$'), '');
    if (!normalizedUrl.startsWith('https://') &&
        !normalizedUrl.startsWith('http://')) {
      normalizedUrl = 'https://' + normalizedUrl;
    }
    normalizedUrl = normalizedUrl.replaceFirst('http://', 'https://');

    final authEndpointUrl = '$normalizedUrl/p/api/fever.php';

    // API Anahtarını Hazırlama
    final isApiKeyFormat = password.length == 32 &&
        RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(password);
    final String finalApiKey = isApiKeyFormat
        ? password
        : md5.convert(utf8.encode('$username:$password')).toString();

    try {
      final response = await _httpClient.post(
        authEndpointUrl,
        data: {
          'api': 'true',
          'api_key': finalApiKey,
          'user_id': 1,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 400 || status == 401),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;

        if (json.containsKey('auth') && json['auth'] == 1) {
          return finalApiKey;
        } else {
          throw Exception(
              '❌ Giriş başarısız: Kullanıcı adı/şifre veya API anahtarı hatalı.');
        }
      } else {
        throw Exception(
            '❌ Fever API geçersiz yanıt veya bilinmeyen hata: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('⚠️ Beklenmeyen bir hata oluştu: $e');
    }
  }

  // ===============================================================
  // 📂 2. Kategorileri Getir (Fever API) - Kategori Sayısı ve Cache Eklendi
  // ===============================================================
  @override
  Future<List<Category>> getCategories(String apiUrl, String token) async {
    final categoriesEndpointUrl = '$apiUrl/p/api/fever.php';

    try {
      final response = await _httpClient.post(
        categoriesEndpointUrl,
        data: {
          'api': 'true',
          'api_key': token,
          'groups': null,
          'user_id': '1',
          'feeds': null, // Feeds bilgisini de çekmek için ekledik
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
          receiveDataWhenStatusError: true,
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;

        if (json.containsKey('auth') &&
            json['auth'] == 1 &&
            json.containsKey('groups')) {
          final groupsJson = json['groups'] as List;
          final feedsGroupsJson = json['feeds_groups'] as List? ?? [];
          final feedsJson = json['feeds'] as List? ?? []; // Feeds listesini al

          // YENİ: Feed ID'den adını eşlemek için cache'i doldur
          _feedIdToName.clear();
          for (var feed in feedsJson) {
            _feedIdToName[feed['id'] as int] =
                feed['title'] as String? ?? 'Bilinmeyen Kaynak';
          }

          // Kategori Eşleştirme Mantığı
          Map<int, List<int>> groupFeeds = {};
          Map<int, int> groupFeedCount = {};
          Map<int, String> groupIdToName = {
            for (var g in groupsJson) g['id'] as int: g['title'] ?? 'Bilinmeyen'
          };

          for (var fg in feedsGroupsJson) {
            final feedIdsString = fg['feed_ids'] as String? ?? '';
            final groupId = fg['group_id'] as int;

            final feedIds = feedIdsString
                .split(',')
                .where((id) => id.trim().isNotEmpty)
                .map((id) => int.tryParse(id.trim()) ?? 0)
                .where((id) => id != 0)
                .toList();

            groupFeeds[groupId] = feedIds;
            groupFeedCount[groupId] = feedIds.length;

            // Feed ID -> Group ID eşleşmesini cache'e kaydet
            for (var feedId in feedIds) {
              _feedIdToGroupId[feedId] = groupId;
            }
          }

          // Category Modellerini Oluştur
          _categoriesCache = groupsJson.map((group) {
            final groupId = group['id'] as int;
            final feedCount = groupFeedCount[groupId] ?? 0;

            return Category(
              id: groupId,
              name: groupIdToName[groupId] ?? 'Bilinmeyen',
              count: feedCount,
              icon: LucideIcons.folder,
              feedIds: groupFeeds[groupId] ?? [], // Alt feed ID'lerini atama
            );
          }).toList();

          // "Hepsi" kategorisini listenin en başına ekle
          List<int> allFeedIds =
              _categoriesCache.expand((cat) => cat.feedIds).toSet().toList();
          int totalFeedCount = allFeedIds.length;

          _categoriesCache.insert(
            0,
            Category(
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
              'Kategoriler alınamadı: Geçersiz API yanıtı veya yetkilendirme hatası.');
        }
      } else {
        throw Exception(
            'Kategoriler alınamadı: Sunucu durumu kodu: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('⚠️ Beklenmeyen bir hata oluştu: $e');
    }
  }

// ===============================================================
// 📰 3. RSS Feed Ögelerini Getir (Fever API) - Maksimum Öğeyi Zorlama
// ===============================================================
  @override
  Future<List<FeedItem>> getFeedItems(String apiUrl, String token) async {
    final feedEndpointUrl = '$apiUrl/p/api/fever.php';

    try {
      final response = await _httpClient.post(
        feedEndpointUrl,
        data: {
          'api': 'true',
          'api_key': token,
          'items': null,
          'user_id': '1',
          'since_id': 0, // En eski öğeden başla
          'max_items': 2000, // Daha yüksek bir limit deniyoruz
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
          receiveDataWhenStatusError: true,
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;

        if (json.containsKey('auth') &&
            json['auth'] == 1 &&
            json.containsKey('items')) {
          final itemsJson = json['items'] as List;

          List<FeedItem> feedItems = (itemsJson).map((item) {
            final int timestamp = item['created_on_time'] as int? ?? 0;
            final String itemUrl = item['url'] as String? ?? '#';
            final int feedId =
                item['feed_id'] as int? ?? 0; // Doğrudan feedId'yi al

            // Kategori Adını Cache'den bulma
            final int groupId = _feedIdToGroupId[feedId] ?? 0;
            final String categoryName = _categoriesCache
                .firstWhere((cat) => cat.id == groupId,
                    orElse: () => Category(
                        id: 0,
                        name: 'Genel',
                        count: 0,
                        icon: LucideIcons.folder,
                        feedIds: []))
                .name;

            // Feed ID'den feed adını al
            final String feedName =
                _feedIdToName[feedId] ?? 'Bilinmeyen Kaynak';

            return FeedItem(
              id: item['id'].hashCode,
              title: item['title'] ?? 'Başlıksız',
              sourceName: feedName, // sourceName olarak feed adını kullandık
              feedId: feedId, // Yeni eklenen feedId alanını doldurduk
              time: _formatTimeAgo(timestamp),
              unread: item['is_read'] == 0,
              category: categoryName,
              url: itemUrl,
              timestamp: timestamp,
            );
          }).toList();

          return feedItems;
        } else {
          throw Exception(
              'Feed öğeleri alınamadı: Geçersiz API yanıtı veya yetkilendirme hatası.');
        }
      } else {
        throw Exception(
            'Feed öğeleri alınamadı: Sunucu durumu kodu: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('⚠️ Beklenmeyen bir hata oluştu: $e');
    }
  }
}
