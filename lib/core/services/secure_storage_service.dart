import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _authTokenKey = 'authToken';
  static const _usernameKey = 'username';
  static const _passwordKey =
      'password'; // Şifreyi saklamak genellikle önerilmez, ancak FreshRSS ClientLogin için gerekli olabilir.
  static const _urlKey = 'url';

  Future<void> saveCredentials({
    required String url,
    required String username,
    required String authToken,
    required String originalPassword, // Şifre isteğe bağlı olabilir
  }) async {
    await _storage.write(key: _urlKey, value: url);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _authTokenKey, value: authToken);
    if (originalPassword != null) {
      await _storage.write(key: _passwordKey, value: originalPassword);
    }
  }

  Future<Map<String, String?>> getCredentials() async {
    final url = await _storage.read(key: _urlKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    final authToken = await _storage.read(key: _authTokenKey);
    return {
      'url': url,
      'username': username,
      'password': password,
      'authToken': authToken,
    };
  }

  Future<String?> getServerUrl() async {
    return await _storage.read(key: _urlKey);
  }

  Future<bool> isUserLoggedIn() async {
    final token = await _storage.read(key: _authTokenKey);
    final url = await _storage.read(key: _urlKey);
    final username = await _storage.read(key: _usernameKey);
    return token != null &&
        token.isNotEmpty &&
        url != null &&
        url.isNotEmpty &&
        username != null &&
        username.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: _authTokenKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _urlKey);
  }

  Future<Map<String, String?>> getCredentialsForRefresh() async {
    // NOT: Bu metot, sizin getCredentials() metodunuzla aynıdır.
    // Tüm bilgileri döndürerek Interceptor'ın ihtiyacı olan username ve password'e erişimini sağlar.

    final url = await _storage.read(key: _urlKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey); // Orijinal şifre
    final authToken =
        await _storage.read(key: _authTokenKey); // Eski (süresi dolmuş) token

    return {
      'url': url,
      'username': username,
      'password': password, // <<< KRİTİK: Yenileme için şifre
      'authToken': authToken,
    };
  }
}
