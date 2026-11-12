import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/token_storage.dart';
import '../../core/utils/json_utils.dart';
import '../models/auth_models.dart';

class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStorage tokens})
      : _api = api,
        _tokens = tokens;

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<String?> lastLabCode() => _tokens.readLabCode();

  Future<bool> hasStoredSession() async {
    final refresh = await _tokens.readRefresh();
    return refresh != null && refresh.isNotEmpty;
  }

  /// POST /auth/login/ - saves both tokens on success.
  Future<LoginResult> login({
    required String username,
    required String password,
    required String tenant,
  }) async {
    final data = await _api.post(
      '/auth/login/',
      auth: false,
      showServerMessage: true,
      body: {
        'username': username,
        'password': password,
        if (tenant.trim().isNotEmpty) 'tenant': tenant.trim(),
      },
    );

    final map = Json.map(data);
    final access = Json.string(map['access']);
    final refresh = Json.string(map['refresh']);
    if (access == null || refresh == null) {
      throw const ApiException(
        ApiErrorKind.unknown,
        'Something went wrong, try again',
      );
    }
    await _tokens.save(access: access, refresh: refresh);
    await _tokens.saveLabCode(tenant.trim());

    final tenantMap = Json.map(map['tenant']);
    return LoginResult(
      access: access,
      refresh: refresh,
      user: AppUser.fromJson(Json.map(map['user'])),
      tenant: tenantMap.isEmpty ? null : TenantInfo.fromJson(tenantMap),
    );
  }

  Future<MeProfile> me() async {
    final data = await _api.get('/auth/me/');
    return MeProfile.fromJson(Json.map(data));
  }

  Future<PermissionSet> permissions() async {
    final data = await _api.get('/auth/me/permissions/');
    return PermissionSet.fromJson(Json.map(data));
  }

  /// POST /auth/logout/ then wipe the tokens. The tokens are removed even if
  /// the call fails (for example when there is no network).
  Future<void> logout() async {
    try {
      final refresh = await _tokens.readRefresh();
      if (refresh != null && refresh.isNotEmpty) {
        await _api.post(
          '/auth/logout/',
          auth: false,
          body: {'refresh': refresh},
        );
      }
    } catch (_) {
      // Ignored on purpose - see the doc comment.
    } finally {
      await _tokens.clear();
    }
  }
}
