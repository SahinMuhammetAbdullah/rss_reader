// lib/features/rss_feed/data/datasources/rss_feed_api_data_source.dart

import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../../../../core/services/secure_storage_service.dart';

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
  Future<void> markItemStatus(
      String apiUrl, String token, String itemId, bool isRead);
  Future<void> markAllAsRead(String apiUrl, String token);
}

// =================================================================
// SOMUT SINIF UYGULAMASI (Google Reader API Uyumlu)
// =================================================================
class RssFeedApiDataSource implements RssFeedDataSource {
  final Dio _httpClient; // <<< Final olarak tanımlayın
  final SecureStorageService _storageService; // <<< Bunu ekleyin
  // Veri Cache'leri
  List<RssCategory> _categoriesCache = [];
  Map<int, int> _feedIdToGroupId = {}; // Feed ID -> Category ID eşleştirme
  Map<int, String> _feedIdToFeedName =
      {}; // Feed ID -> Feed Adı (Source Name) eşleştirme

  RssFeedApiDataSource(
      {required SecureStorageService
          storageService}) // <<< Constructor'ı güncelleyin
      : _httpClient = Dio(), // Burada başlatın
        _storageService = storageService // Enjekte edilen servisi atayın
  {
    _setupHttpClientForDev();
    _setupDioInterceptors();
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
    final streamEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list?output=json';

    try {
      final response = await _httpClient.get(
        streamEndpointUrl,
        queryParameters: {'n': 'max', 'r': 'd'},
        options: Options(
          headers: {'Authorization': 'GoogleLogin auth=$token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;
        final itemsJson = json['items'] as List? ?? [];
        List<FeedItem> feedItems = [];

        // Bu kısım, API'den gelen veriyi modelimize dönüştürür.
        for (var item in itemsJson) {
          final int feedId =
              int.tryParse(item['feed_id']?.toString() ?? '0') ?? 0;
          final String title = item['title'] as String? ?? 'Başlıksız';
          final int timestamp = (item['published'] as int? ?? 0);
          final String itemUrl = item['alternate'] != null &&
                  (item['alternate'] as List).isNotEmpty
              ? (item['alternate'] as List).first['href'] as String? ?? '#'
              : '#';
          final String finalItemIdStr = item['id'] as String? ??
              item['id'].toString(); // ID'yi string olarak al
          final List categories = item['categories'] as List? ?? [];
          final bool isRead =
              categories.contains('user/-/state/com.google/read');

          // Kaynak ve Kategori Adını Cache'den Çekme
          final String sourceName = _feedIdToFeedName[feedId] ??
              item['origin']?['title'] as String? ??
              'Bilinmeyen Kaynak';
          final int groupId = _feedIdToGroupId[feedId] ?? 0;
          final String categoryName = _categoriesCache
                  .firstWhereOrNull((cat) => cat.id == groupId)
                  ?.name ??
              'Genel';

          feedItems.add(
            FeedItem(
              id: finalItemIdStr,
              title: title,

              // ❌ HATA BURADAYDI: Constructor 'source' bekliyor.
              // sourceName: sourceName, // Yanlış etiket

              // ✅ DÜZELTME: sourceName değişkenini 'source' etiketine atıyoruz.
              source: sourceName, // Kaynak Adı

              feedId: feedId, // Filtreleme için ID
              time: _formatTimeAgo(timestamp),
              unread: !isRead, // OKUNDU DURUMU
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

  // Eksik Dio Helper'ı Ekle
  void _setupDioInterceptors() {
    _httpClient.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          if (e.response?.statusCode == 401 &&
              !e.requestOptions.path.contains('/accounts/ClientLogin')) {
            print(
                '🚨 401 Yetkisiz hata alındı. Token yenilemeye çalışılıyor...');

            // Kaydedilmiş kimlik bilgilerini _storageService üzerinden al
            final credentials =
                await _storageService.getCredentials(); // <<< Burayı değiştirin

            final String? storedUsername = credentials['username'];
            final String? storedPassword = credentials['password'];
            final String? storedApiUrl = credentials['url'];

            if (storedUsername != null &&
                storedPassword != null &&
                storedApiUrl != null) {
              try {
                final newToken = await getNewToken(
                    storedApiUrl, storedUsername, storedPassword);
                print('✅ Yeni token başarıyla alındı.');

                // Yeni token'ı _storageService üzerinden güncelle
                // (saveCredentials, url, username ve password'u da tekrar kaydeder, bu uygun)
                await _storageService.saveCredentials(
                  url: storedApiUrl, // Mevcut URL'yi tekrar kaydet
                  username:
                      storedUsername, // Mevcut kullanıcı adını tekrar kaydet
                  authToken: newToken, // Yeni token'ı kaydet
                );

                e.requestOptions.headers['Authorization'] =
                    'GoogleLogin auth=$newToken';
                print(
                    '🔄 Orijinal istek yeni token ile tekrar gönderiliyor...');
                return handler
                    .resolve(await _httpClient.fetch(e.requestOptions));
              } catch (refreshError) {
                print('❌ Token yenileme başarısız oldu: $refreshError');
                return handler.next(e);
              }
            } else {
              print(
                  '⚠️ Saklanmış kimlik bilgileri bulunamadı. Kullanıcı yeniden giriş yapmalı.');
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // YENİ METOT: Makalenin okundu/okunmadı durumunu sunucuda günceller

  Future<String> _getActionToken(String apiUrl, String token) async {
    // Önce token'ı debug et
    _debugToken(token);

    final normalizedUrl = _normalizeUrl(apiUrl);
    final tokenEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/token';

    // Token'ı temizle - sadece token kısmını al
    final cleanToken = token.contains('/') ? token.split('/').last : token;

    print('🔑 Action Token İsteği:');
    print('  URL: $tokenEndpointUrl');
    print('  Clean Token: $cleanToken');

    try {
      final response = await _httpClient.get(
        tokenEndpointUrl,
        options: Options(
          headers: {'Authorization': 'GoogleLogin auth=$cleanToken'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('🔑 Token Yanıtı:');
      print('  Status: ${response.statusCode}');
      print('  Data: ${response.data}');
      print('  Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final String actionToken = response.data.toString().trim();
        if (actionToken.isNotEmpty) {
          print('✅ Action Token başarıyla alındı: $actionToken');
          return actionToken;
        } else {
          throw Exception('Action token boş döndü');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Ana token geçersiz veya süresi dolmuş');
      } else {
        throw Exception('Token alınamadı. Status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Token Alma Hatası: ${e.message}');
      if (e.response != null) {
        print('❌ Detay: ${e.response?.statusCode} - ${e.response?.data}');
      }
      throw Exception('Action token alınamadı: ${e.message}');
    }
  }

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

@override
Future<void> markItemStatus(String apiUrl, String token, String itemId, bool isRead) async {
    // 1. Action Token'ı çek (Her zaman gerekli)
    final String actionToken;
    try {
        actionToken = await _getActionToken(apiUrl, token);
    } catch (e) {
        throw Exception('Action Token Alınamadı: Durum güncelleme iptal edildi. Detay: ${e.toString()}');
    }

    // 2. Aksiyon Değişkenleri
    final endpointUrl = '$apiUrl/p/api/greader.php/reader/api/0/edit-tag'; 
    final String actionType = isRead ? 'a' : 'r'; 
    final String tag = 'user/-/state/com.google/read';
    final String itemIdTag = 'tag:google.com,2005:reader/item/${itemId}'; // Item ID String olarak

    try {
        final response = await _httpClient.post(
            endpointUrl,
            data: {
                // T parametresine Action Token'ı gönderiyoruz
                'T': actionToken,        
                'i': itemIdTag,          // Makale ID'si
                'ac': actionType,       
                's': tag,               
            },
            options: Options(
                // KRİTİK: GRAPI POST isteklerinde Content-Type zorunludur.
                contentType: Headers.formUrlEncodedContentType,
                // Yetkilendirme Header'ı
                headers: {'Authorization': 'GoogleLogin auth=$token'}, 
            ),
        );

        if (response.statusCode == 200 && response.data.toString().trim() == 'OK') {
            return; // BAŞARI!
        }
        
        // Sunucudan 200 OK geldi ama body 'OK' değilse hata fırlat.
        throw Exception('Durum güncelleme başarısız: Sunucu yanıtı beklenmedik (${response.data}).');

    } on DioException catch (e) {
        // Hata: 401 Unauthorized (GRAPI'de kalma kararı)
        final statusCode = e.response?.statusCode ?? 0;
        if (statusCode == 401) {
            throw Exception('Sunucu durumu güncelleyemedi: 401 Yetkisiz. Action Token kontrolü başarısız.');
        }
        throw Exception('Sunucu durumu güncelleyemedi (GRAPI Dio Hatası: ${e.message})');
    } catch (e) {
        throw Exception('Sunucu güncelleme hatası: $e');
    }
}
  // Token'ı debug etmek için yardımcı metod
  void _debugToken(String token) {
    print('🔐 TOKEN ANALİZİ:');
    print('  Orijinal Token: $token');
    print('  Uzunluk: ${token.length}');

    if (token.contains('/')) {
      final parts = token.split('/');
      print('  Kullanıcı Adı: ${parts[0]}');
      print('  Token Kısmı: ${parts[1]}');
      print('  Token Uzunluğu: ${parts[1].length}');
    }

    // Geçerli bir token genellikle 40 karakter uzunluğunda olmalı
    final cleanToken = token.contains('/') ? token.split('/').last : token;
    if (cleanToken.length != 40) {
      print(
          '  ⚠️  UYARI: Token uzunluğu beklenenden farklı (${cleanToken.length} karakter)');
    }
  }

// RssFeedApiDataSource sınıfına bu metodu ekleyin:
  @override // getNewToken'ı RssFeedDataSource içine eklediyseniz, @override kullanın
  Future<String> getNewToken(
      String apiUrl, String username, String password) async {
    final normalizedUrl = _normalizeUrl(apiUrl);
    final authEndpointUrl =
        '$normalizedUrl/p/api/greader.php/accounts/ClientLogin';

    print('🔄 YENİ TOKEN ALINIYOR:');
    print('  URL: $authEndpointUrl');
    print('  Kullanıcı: $username');

    try {
      final response = await _httpClient.post(
        authEndpointUrl,
        data: {
          'Email': username,
          'Passwd': password,
          'client': 'FlutterRSSReader',
          'accountType': 'HOSTED_OR_GOOGLE',
          'service': 'reader',
          'output': 'json',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('🔑 Token Alma Yanıtı:');
      print('  Status: ${response.statusCode}');
      print('  Data: ${response.data}');

      if (response.statusCode == 200) {
        final responseText = response.data.toString();
        print('  Raw Response: $responseText');

        final lines = responseText.split('\n');
        String? authToken;

        for (final line in lines) {
          if (line.startsWith('Auth=')) {
            authToken = line.substring(5).trim();
            break;
          }
        }

        if (authToken != null && authToken.isNotEmpty) {
          print('✅ YENİ TOKEN BAŞARIYLA ALINDI: $authToken');
          print('✅ Token Uzunluğu: ${authToken.length}');
          // Yeni tokenı SecureStorageService üzerinden kaydet
          await _storageService.saveCredentials(
              url: _normalizeUrl(apiUrl), // Mevcut API URL'sini tekrar kaydet
              username: username,
              authToken: authToken); // <<< Burayı değiştirin
          return authToken;
        } else {
          throw Exception(
              'Token response içinde bulunamadı. Response: $responseText');
        }
      } else if (response.statusCode == 403) {
        throw Exception(
            'Erişim reddedildi. Kullanıcı adı/şifre hatalı veya hesap kısıtlaması var.');
      } else if (response.statusCode == 401) {
        throw Exception(
            'Kimlik doğrulama başarısız. Kullanıcı adı/şifre hatalı.');
      } else {
        throw Exception(
            'Authentication failed: ${response.statusCode} - ${response.data}');
      }
    } on DioException catch (e) {
      print('❌ Token Alma Hatası: ${e.message}');
      if (e.response != null) {
        print('❌ Detay: ${e.response?.statusCode} - ${e.response?.data}');
      }
      throw Exception('Authentication error: ${e.message}');
    }
  }

  Future<void> testCurrentToken(String apiUrl, String currentToken) async {
    print('🧪 MEVCUT TOKEN TESTİ BAŞLADI');
    final normalizedUrl = _normalizeUrl(apiUrl);
    final testEndpointUrl =
        '$normalizedUrl/p/api/greader.php/reader/api/0/user-info';

    // Token’ı temizle (bazı durumlarda username/token formatında geliyor)
    final cleanToken = currentToken.contains('/')
        ? currentToken.split('/').last
        : currentToken;

    try {
      final response = await _httpClient.get(
        testEndpointUrl,
        options: Options(
          headers: {'Authorization': 'GoogleLogin auth=$cleanToken'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('🔍 Token Test Yanıtı:');
      print('  Status: ${response.statusCode}');
      print('  Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Token geçerli. Kullanıcı bilgileri alındı.');
      } else if (response.statusCode == 401) {
        print('❌ Token geçersiz veya süresi dolmuş.');
      } else {
        print('⚠️ Beklenmedik yanıt: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Token Testi Hatası: ${e.message}');
      if (e.response != null) {
        print('❌ Detay: ${e.response?.statusCode} - ${e.response?.data}');
      }
    } catch (e) {
      print('⚠️ Beklenmeyen hata (Token Test): $e');
    }
  }
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
