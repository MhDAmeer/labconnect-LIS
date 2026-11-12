import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/services/report_service.dart';
import '../data/models/auth_models.dart';
import '../data/repositories/auth_repository.dart';

enum SessionStatus {
  /// Checking secure storage on start-up.
  starting,
  signedOut,
  signedIn,
}

/// Owns "who is logged in": tokens (through the repository), the profile,
/// the permission list and the facility the user picked.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository auth,
    required ReportService reports,
  })  : _auth = auth,
        _reports = reports;

  final AuthRepository _auth;
  final ReportService _reports;

  SessionStatus _status = SessionStatus.starting;
  MeProfile? _profile;
  PermissionSet _permissions = const PermissionSet.empty();
  TenantInfo? _tenant;
  int? _facilityId;

  /// One-off text for the login screen ("Your session has expired...").
  String? _notice;

  SessionStatus get status => _status;
  AppUser? get user => _profile?.user;
  PermissionSet get permissions => _permissions;
  TenantInfo? get tenant => _tenant;
  List<AssignedFacility> get facilities =>
      _profile?.assignedFacilities ?? const [];

  /// The facility sent as `facility_id` on list calls. Null means "all of the
  /// user's facilities" (the server's default).
  int? get facilityId => _facilityId;

  AssignedFacility? get selectedFacility {
    for (final f in facilities) {
      if (f.facilityId == _facilityId) return f;
    }
    return null;
  }

  /// Returns the pending notice once, then forgets it.
  String? takeNotice() {
    final text = _notice;
    _notice = null;
    return text;
  }

  // ---------------------------------------------------------------------------

  /// App start: if a refresh token is saved, try to load the profile with it.
  /// The API client refreshes the access token on its own when needed.
  Future<void> restore() async {
    try {
      if (!await _auth.hasStoredSession()) {
        _setSignedOut();
        return;
      }
      await _loadProfile();
      _status = SessionStatus.signedIn;
      notifyListeners();
    } on ApiException catch (e) {
      // Offline or a server hiccup: the saved tokens are left alone, the
      // user just sees the reason on the Login screen. (An expired session
      // already set its own notice through the API client.)
      if (e.kind != ApiErrorKind.unauthorized) _notice = e.message;
      _setSignedOut();
    } catch (_) {
      _setSignedOut();
    }
  }

  Future<void> login({
    required String username,
    required String password,
    required String tenantCode,
  }) async {
    final result = await _auth.login(
      username: username.trim(),
      password: password,
      tenant: tenantCode.trim(),
    );
    _tenant = result.tenant;

    try {
      await _loadProfile();
    } catch (_) {
      // Half a login is worse than none: drop the tokens and report.
      await _auth.logout();
      rethrow;
    }
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  /// GET /auth/me/ and /auth/me/permissions/, then pick the facility.
  Future<void> _loadProfile() async {
    final results = await Future.wait<Object>([
      _auth.me(),
      _auth.permissions(),
    ]);
    _profile = results[0] as MeProfile;
    _permissions = results[1] as PermissionSet;

    final available = _profile!.assignedFacilities;
    final keep = available.any((f) => f.facilityId == _facilityId);
    if (!keep) {
      _facilityId = _pickDefaultFacility(_profile!);
    }
  }

  int? _pickDefaultFacility(MeProfile profile) {
    final list = profile.assignedFacilities;
    if (list.isEmpty) return profile.activeFacilityId;
    final active = profile.activeFacilityId;
    if (active != null && list.any((f) => f.facilityId == active)) {
      return active;
    }
    final marked = list.where((f) => f.isDefault);
    return marked.isNotEmpty ? marked.first.facilityId : list.first.facilityId;
  }

  void selectFacility(int? id) {
    if (id == _facilityId) return;
    _facilityId = id;
    notifyListeners();
  }

  /// Logout from any screen. Everything local is cleared, also when the
  /// server call fails.
  Future<void> logout({String? notice}) async {
    await _auth.logout();
    await _reports.clearCache();
    _notice = notice;
    _setSignedOut();
  }

  /// The refresh token was refused, or the app was away for too long.
  Future<void> endSession(String message) async {
    if (_status == SessionStatus.signedOut) return;
    await _reports.clearCache();
    _notice = message;
    _setSignedOut();
  }

  void _setSignedOut() {
    _profile = null;
    _permissions = const PermissionSet.empty();
    _tenant = null;
    _facilityId = null;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }
}
