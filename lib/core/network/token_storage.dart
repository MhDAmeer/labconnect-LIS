import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the two JWTs in the platform's secure storage (Keychain / Keystore).
///
/// The password is never stored anywhere.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _accessKey = 'lc_access_token';
  static const _refreshKey = 'lc_refresh_token';
  static const _tenantKey = 'lc_last_lab_code';

  final FlutterSecureStorage _storage;

  Future<String?> readAccess() => _read(_accessKey);
  Future<String?> readRefresh() => _read(_refreshKey);

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  /// The lab code is not a secret and is the same every day, so it is kept
  /// to save typing. It survives logout on purpose.
  Future<String?> readLabCode() => _read(_tenantKey);
  Future<void> saveLabCode(String code) =>
      _storage.write(key: _tenantKey, value: code);

  /// Both tokens go together - the refresh token rotates on every use.
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // A corrupted keystore entry should behave like "not logged in"
      // instead of crashing the app on start-up.
      await clear().catchError((_) {});
      return null;
    }
  }
}
