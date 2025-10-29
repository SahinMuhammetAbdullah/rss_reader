// lib/core/services/secure_storage_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const String _keyServerUrl = 'server_url';
  static const String _keyUsername = 'username';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyIsLoggedIn = 'is_logged_in';
  
  Future<String?> getServerUrl() async {
    return await _storage.read(key: _keyServerUrl);
  }

  // Giriş Bilgilerini Kaydetme
  Future<void> saveCredentials({
    required String url,
    required String username,
    required String authToken, // Artık sadece authToken parametresini bekliyor
  }) async {
    await _storage.write(key: _keyServerUrl, value: url);
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyAuthToken, value: authToken);
    await _storage.write(key: _keyIsLoggedIn, value: 'true');
  }

  // Giriş Bilgilerini Alma
  Future<Map<String, String?>> getCredentials() async {
    final url = await _storage.read(key: _keyServerUrl);
    final authToken = await _storage.read(key: _keyAuthToken);

    return {
      'url': url,
      'authToken': authToken, // Bu etiket kullanılmalı
    };
  }

  // Oturum Durumunu Kontrol Etme
  Future<bool> isUserLoggedIn() async {
    final status = await _storage.read(key: _keyIsLoggedIn);
    return status == 'true';
  }

  // Oturumu Kapatma
  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
