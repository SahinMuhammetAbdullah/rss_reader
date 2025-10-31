// lib/features/rss_feed/data/datasources/rss_feed_api_data_source.dart

import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../../domain/models/feed_item.dart';
import '../../../../core/services/secure_storage_service.dart';

final Dio _httpClient = Dio();

// =================================================================
// YARDIMCI FONKSİYONLAR VE UZANTILAR
// =================================================================

void _setupHttpClientForDev() {
  if (kDebugMode && (Platform.isAndroid || Platform.isIOS)) {
    _httpClient.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
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

extension RssCategoryListExtension on List<RssCategory> {
  RssCategory? firstWhereOrNull(bool Function(RssCategory) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// =================================================================
// ABSTRACT SINIF TANIMI
// =================================================================
abstract class RssFeedDataSource {
  Future<String> authenticate(String url, String username, String password);
  Future<List<RssCategory>> getCategories(String apiUrl, String token);
  Future<List<FeedItem>> getFeedItems(String apiUrl, String token);
  Future<void> markItemStatus(
      String apiUrl, String token, String itemId, bool isRead);
  Future<void> markAllAsRead(String apiUrl, String token);
}

// =================================================================
// SOMUT SINIF UYGULAMASI (Google Reader API Uyumlu)
// =================================================================
class RssFeedApiDataSource implements RssFeedDataSource {
  final SecureStorageService _storageService;

  List<RssCategory> _categoriesCache = [];
  Map<int, int> _feedIdToGroupId = {};
  Map<int, String> _feedIdToFeedName = {};

  String? _cachedActionToken;

  RssFeedApiDataSource({required SecureStorageService storageService})
      : _storageService = storageService {
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

  // YARDIMCI METOT: CLIENTLOGIN İLE YENİ ANA TOKEN ÇEKME
  // Bu metot sadece ana token (Auth=...) süresi dolduğunda veya ilk kez alındığında kullanılmalı.
  // PHP tarafındaki `clientLogin` işlevine karşılık gelir.
  Future<String> _getNewMainToken(
      String apiUrl, String username, String password) async {
    final normalizedUrl = _normalizeUrl(apiUrl);
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
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (response.statusCode == 200 && response.data is String) {
        final tokenMatch =
            RegExp(r'Auth=(.+)\n?').firstMatch(response.data.toString());
        if (tokenMatch != null && tokenMatch.group(1) != null) {
          final newToken = tokenMatch.group(1)!;
          // >>> ÖNEMLİ: YENİ ANA TOKEN'I GÜVENLİ DEPOLAMAYA KAYDET <<<
          await _storageService.saveCredentials(
            url: apiUrl, // apiUrl, currentApiUrl değil
            username: username,
            authToken: newToken,
            // KRİTİK: Orijinal şifreyi de kaydetmemiz gerekiyor
            originalPassword: password,
          );
          return newToken;
        }
      }
      throw Exception(
          'Token yenileme başarısız: Sunucu yanıtında Auth token bulunamadı.');
    } on DioException catch (e) {
      throw Exception('Token yenileme başarısız: Dio Hatası (${e.message})');
    }
  }

  // YARDIMCI METOT: ACTION TOKEN ALMA (veya cache'ten kullanma)
  // Bu metot aynı zamanda ana token'ın (Auth=...) geçersiz olması durumunu da ele alır.
  Future<String> _getActionToken(String apiUrl, String token) async {
    final normalizedUrl = _normalizeUrl(apiUrl);
    final tokenEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/token';

    try {
      final response = await _httpClient.get(
        tokenEndpointUrl,
        options: Options(
          headers: {'Authorization': 'GoogleLogin auth=$token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is String) {
        final String actionToken = response.data.toString().trim();
        if (actionToken.isNotEmpty) {
          if (kDebugMode) print('✅ Action Token başarıyla alındı.');
          return actionToken;
        }
      }
      throw Exception('Action token alınamadı: Sunucu geçersiz yanıt verdi.');
    } on DioException catch (e) {
      throw Exception('Action token alınırken Dio Hatası: ${e.message}');
    }
  }

  // Ortak bir API çağrı işleyicisi oluşturalım.
  // Bu işleyici, 401 hatalarını yakalayıp token'ı yenileme ve işlemi yeniden deneme mantığını içerecek.
  Future<Response> _performApiCall(
      Future<Response> Function(String currentMainToken) apiCall,
      String initialMainToken,
      String apiUrl,
      String username,
      String password) async {
    String currentMainToken = initialMainToken;
    int retryCount = 0;
    const maxRetries = 1; // Genellikle 1 retry yeterli olur

    while (retryCount <= maxRetries) {
      try {
        return await apiCall(currentMainToken);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          print('API çağrısı 401 Unauthorized döndü. Token yenileniyor...');
          // Sadece bir kere yenileme denemesi yapalım
          if (retryCount == 0) {
            try {
              final credentials =
                  await _storageService.getCredentialsForRefresh();
              currentMainToken =
                  await _getNewMainToken(apiUrl, username, password);
              _cachedActionToken = null; // Action token'ı da sıfırla
              retryCount++;
              final String newAuthToken = await _getNewMainToken(
                  credentials['url']!,
                  credentials['username']!,
                  credentials['password']!);
              await _storageService.saveCredentials(
                url: credentials['url']!,
                username: credentials['username']!,
                authToken: newAuthToken,
                originalPassword:
                    credentials['password']!, // Yenileme için kullanılan şifre
              );

              currentMainToken = newAuthToken; // Token'ı güncelle
              retryCount++;
              print('Token başarıyla yenilendi, işlem yeniden deneniyor.');
              continue;
            } catch (refreshError) {
              print('Ana Token yenileme sırasında hata oluştu: $refreshError');
              rethrow; // Yenileme hatasını yukarı fırlat
            }
          } else {
            rethrow; // Yeniden deneme limitini aştık, hatayı fırlat
          }
        }
        rethrow; // Diğer Dio hatalarını fırlat
      } catch (e) {
        rethrow; // Diğer hataları fırlat
      }
    }
    throw Exception(
        'API çağrısı başarısız oldu ve yeniden deneme limitine ulaşıldı.');
  }

  // ===============================================================
  // 🔐 1. Kimlik Doğrulama (GRAPI: ClientLogin)
  // ===============================================================
  @override
  Future<String> authenticate(
      String url, String username, String password) async {
    final normalizedUrl = _normalizeUrl(url);
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
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 400 || status == 401),
        ),
      );

      if (response.statusCode == 200 && response.data is String) {
        final tokenMatch =
            RegExp(r'Auth=(.+)\n?').firstMatch(response.data.toString());
        if (tokenMatch != null && tokenMatch.group(1) != null) {
          // Başarılı kimlik doğrulamasında _cachedActionToken'ı sıfırla,
          // yeni bir ana token alındığında action token'ın da yeniden alınması gerekir.
          _cachedActionToken = null;
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
    final tagsEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/tag/list?output=json';
    final subscriptionsEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/subscription/list?output=json';

    final credentials = await _storageService.getCredentials();
    final username = credentials['username']!;
    final password = credentials['password']!;

    try {
      final tagsResponse = await _performApiCall(
        (currentMainToken) async => await _httpClient.get(tagsEndpointUrl,
            options: Options(headers: {
              'Authorization': 'GoogleLogin auth=$currentMainToken'
            })),
        token,
        apiUrl,
        username,
        password,
      );

      final subscriptionsResponse = await _performApiCall(
        (currentMainToken) async => await _httpClient.get(
            subscriptionsEndpointUrl,
            options: Options(headers: {
              'Authorization': 'GoogleLogin auth=$currentMainToken'
            })),
        token,
        apiUrl,
        username,
        password,
      );

      if (tagsResponse.statusCode == 200 &&
          subscriptionsResponse.statusCode == 200) {
        final tagsJson = tagsResponse.data['tags'] as List? ?? [];
        final subscriptionsJson =
            subscriptionsResponse.data['subscriptions'] as List? ?? [];

        _feedIdToFeedName.clear();
        _feedIdToGroupId.clear();

        for (var sub in subscriptionsJson) {
          final String feedIdStr = sub['id'] as String? ?? '';
          final String feedTitle =
              sub['title'] as String? ?? 'Bilinmeyen Kaynak';
          final int? parsedFeedId =
              int.tryParse(feedIdStr.replaceAll('feed/', ''));
          final int feedId = parsedFeedId ?? feedIdStr.hashCode;

          _feedIdToFeedName[feedId] = feedTitle;

          final List categoriesOfFeed = sub['categories'] as List? ?? [];
          if (categoriesOfFeed.isNotEmpty) {
            final String tagId = categoriesOfFeed.first['id'] as String? ?? '';
            final String categoryName = tagId.split('/').lastWhere(
                (element) => element.isNotEmpty,
                orElse: () => 'Genel');
            final int categoryId = categoryName.hashCode;
            _feedIdToGroupId[feedId] = categoryId;
          } else {
            _feedIdToGroupId[feedId] = 'Genel'.hashCode;
          }
        }

        Map<int, List<int>> groupFeeds = {};
        Map<int, int> groupFeedCount = {};
        Map<int, String> groupIdToName = {};

        for (var tag in tagsJson) {
          final String tagId = tag['id'] as String? ?? '';
          if (tagId.contains('user/-/label/')) {
            final String tagName = tagId.split('/').lastWhere(
                (element) => element.isNotEmpty,
                orElse: () => 'Genel');
            final int categoryId = tagName.hashCode;

            groupIdToName[categoryId] = tagName;
            groupFeeds[categoryId] = [];
            groupFeedCount[categoryId] = 0;
          }
        }
        if (groupIdToName.isEmpty && _feedIdToFeedName.isNotEmpty) {
          groupIdToName['Genel'.hashCode] = 'Genel';
          groupFeeds['Genel'.hashCode] = [];
          groupFeedCount['Genel'.hashCode] = 0;
        }

        _feedIdToFeedName.keys.forEach((feedId) {
          final int groupId = _feedIdToGroupId[feedId] ?? 'Genel'.hashCode;
          if (!groupIdToName.containsKey(groupId)) {
            groupIdToName[groupId] = 'Genel';
            groupFeeds[groupId] = [];
            groupFeedCount[groupId] = 0;
          }
          groupFeeds[groupId]!.add(feedId);
          groupFeedCount[groupId] = (groupFeedCount[groupId] ?? 0) + 1;
        });

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

        List<int> allFeedIds = _feedIdToFeedName.keys.toList();
        int totalFeedCount = allFeedIds.length;
        _categoriesCache.insert(
          0,
          RssCategory(
              name: "Hepsi",
              count: totalFeedCount,
              icon: LucideIcons.home,
              id: 0,
              feedIds: allFeedIds),
        );

        return _categoriesCache;
      } else {
        throw Exception(
            '❌ Kategoriler alınamadı: GRAPI sunucu durumu kodu: Tags: ${tagsResponse.statusCode}, Subscriptions: ${subscriptionsResponse.statusCode}');
      }
    } on DioException catch (e) {
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
    final streamEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list?output=json';

    final credentials = await _storageService.getCredentials();
    final username = credentials['username']!;
    final password = credentials['password']!;

    try {
      final response = await _performApiCall(
        (currentMainToken) async => await _httpClient.get(
          streamEndpointUrl,
          queryParameters: {'n': 10000, 'r': 'd'},
          options: Options(
            headers: {'Authorization': 'GoogleLogin auth=$currentMainToken'},
            validateStatus: (status) => status != null && status < 500,
          ),
        ),
        token,
        apiUrl,
        username,
        password,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;
        final itemsJson = json['items'] as List? ?? [];
        List<FeedItem> feedItems = [];

        for (var item in itemsJson) {
          final String rawItemId = item['id'] as String? ?? '';
          String itemId;
          if (rawItemId.startsWith('tag:')) {
            itemId = rawItemId.split('/').last;
          } else {
            itemId = rawItemId;
          }
          final String title = item['title'] as String? ?? 'Başlıksız';
          final int timestamp = (item['published'] as int? ?? 0);
          final String itemUrl = item['alternate'] != null &&
                  (item['alternate'] as List).isNotEmpty
              ? (item['alternate'] as List).first['href'] as String? ?? '#'
              : '#';
          final List categories = item['categories'] as List? ?? [];
          final bool isRead =
              categories.contains('user/-/state/com.google/read');

          final String feedIdStr = item['origin']?['streamId'] as String? ?? '';
          final int? parsedFeedId =
              int.tryParse(feedIdStr.replaceAll('feed/', ''));
          final int feedId = parsedFeedId ?? feedIdStr.hashCode;

          final String sourceName = _feedIdToFeedName[feedId] ??
              item['origin']?['title'] as String? ??
              'Bilinmeyen Kaynak';
          final int groupId = _feedIdToGroupId[feedId] ?? 'Genel'.hashCode;
          final String categoryName = _categoriesCache
                  .firstWhereOrNull((cat) => cat.id == groupId)
                  ?.name ??
              'Genel';

          feedItems.add(
            FeedItem(
              id: itemId,
              title: title,
              source: sourceName,
              feedId: feedId,
              time: _formatTimeAgo(timestamp),
              unread: !isRead,
              category: categoryName,
              url: itemUrl,
              timestamp: timestamp,
            ),
          );
        }
        return feedItems;
      } else {
        throw Exception(
            '❌ Feed öğeleri alınamadı: GRAPI sunucu durumu kodu: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('⚠️ Dio Hatası oluştu (Feed Öğeleri): ${e.message}');
    } catch (e) {
      throw Exception('⚠️ Beklenmeyen hata (Feed Öğeleri): $e');
    }
  }

  // ===============================================================
  // 4. Mark Item Status (Okundu/Okunmadı) (GRAPI: edit-tag)
  // ===============================================================
  @override
  Future<void> markItemStatus(
      String apiUrl, String token, String itemId, bool isRead) async {
    final normalizedUrl = _normalizeUrl(apiUrl);
    final endpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/edit-tag';

    // Action Token'ı çek. Eğer Main Token geçersizse, _getActionToken yenilemeyi dener.
    final String actionToken = await _getActionToken(apiUrl, token);


    // Makale durumu etiketi: Bu etiketi eklemek/kaldırmak makaleyi okundu/okunmadı yapar.
    final String tagToModify = 'user/-/state/com.google/read';

    final Map<String, dynamic> requestData = {
      'T': actionToken,
      'i': itemId, // Makale ID'si
    };

    if (isRead) {
      // Okundu olarak işaretle: 'read' etiketini EKLE (add tag)
      requestData['a'] = tagToModify;
    } else {
      // Okunmadı olarak işaretle: 'read' etiketini KALDIR (remove tag)
      requestData['r'] = tagToModify;
    }

    try {
      final response = await _httpClient.post(
        endpointUrl,
        data: requestData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Authorization': 'GoogleLogin auth=$token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          throw Exception('Token geçersiz. Lütfen tekrar giriş yapın.');
        }
        throw Exception(
            'Makale durumu güncellenemedi. Durum Kodu: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Token geçersiz. Lütfen tekrar giriş yapın.');
      }
      throw Exception('API Hatası (Mark Status): ${e.message}');
    }
  }

// ===============================================================
// 5. Mark All As Read (Toplu Okundu) (GRAPI: mark-all-as-read)
// ===============================================================
  @override
  Future<void> markAllAsRead(String apiUrl, String token) async {
    final endpointUrl =
        '$apiUrl/p/api/greader.php/reader/api/0/mark-all-as-read';
    final actionToken =
        await _getActionToken(apiUrl, token); // Action Token çekilir

    try {
      final response = await _httpClient.post(
        endpointUrl,
        data: {
          'T': actionToken,
          's': 'user/-/state/com.google/reading-list', // Tüm akışı işaretle
          'ts': (DateTime.now().millisecondsSinceEpoch * 1000)
              .toString(), // Zaman damgası
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Authorization': 'GoogleLogin auth=$token'},
        ),
      );

      if (response.statusCode == 200 &&
          response.data.toString().trim() == 'OK') {
        print('✅ TÜM FEEDLER GRAPI ÜZERİNDEN OKUNDU OLARAK İŞARETLENDİ.');
        return;
      }
      throw Exception('Toplu okundu işareti başarısız: Yanıt beklenmedik.');
    } on DioException {
      throw Exception('Toplu okundu işaretleme hatası.');
    }
  }
}
