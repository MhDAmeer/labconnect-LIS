import '../../core/utils/json_utils.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    this.email,
    this.firstName = '',
    this.lastName = '',
    this.role,
  });

  final int id;
  final String username;
  final String? email;
  final String firstName;
  final String lastName;
  final String? role;

  String get fullName => '$firstName $lastName'.trim();

  /// Name to greet the user with on Home.
  String get greetingName {
    if (firstName.isNotEmpty) return firstName;
    return username;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: Json.integer(json['id']) ?? 0,
      username: Json.text(json['username']),
      email: Json.string(json['email']),
      firstName: Json.text(json['first_name']),
      lastName: Json.text(json['last_name']),
      role: Json.nameOf(json['role']),
    );
  }
}

/// One entry of `assigned_facilities` in `/auth/me/`.
class AssignedFacility {
  const AssignedFacility({
    required this.facilityId,
    required this.name,
    required this.code,
    required this.isDefault,
  });

  final int facilityId;
  final String name;
  final String code;
  final bool isDefault;

  factory AssignedFacility.fromJson(Map<String, dynamic> json) {
    return AssignedFacility(
      facilityId: Json.integer(json['facility_id']) ?? 0,
      name: Json.text(json['facility_name']),
      code: Json.text(json['facility_code']),
      isDefault: Json.boolean(json['is_default']),
    );
  }
}

class TenantInfo {
  const TenantInfo({required this.name, required this.slug});

  final String name;
  final String slug;

  factory TenantInfo.fromJson(Map<String, dynamic> json) {
    return TenantInfo(
      name: Json.text(json['name']),
      slug: Json.text(json['slug']),
    );
  }
}

/// Result of `POST /auth/login/` (tokens are handled separately and saved
/// straight to secure storage).
class LoginResult {
  const LoginResult({
    required this.access,
    required this.refresh,
    required this.user,
    this.tenant,
  });

  final String access;
  final String refresh;
  final AppUser user;
  final TenantInfo? tenant;
}

/// Result of `GET /auth/me/`.
class MeProfile {
  const MeProfile({
    required this.user,
    required this.activeFacilityId,
    required this.assignedFacilities,
  });

  final AppUser user;
  final int? activeFacilityId;
  final List<AssignedFacility> assignedFacilities;

  factory MeProfile.fromJson(Map<String, dynamic> json) {
    final active = json['active_facility'];
    int? activeId;
    if (active is Map) {
      activeId = Json.integer(active['facility_id'] ?? active['id']);
    } else {
      activeId = Json.integer(active);
    }

    return MeProfile(
      user: AppUser.fromJson(json),
      activeFacilityId: activeId,
      assignedFacilities: Json.list(json['assigned_facilities'])
          .map((e) => AssignedFacility.fromJson(Json.map(e)))
          .where((f) => f.facilityId != 0)
          .toList(),
    );
  }
}

/// Result of `GET /auth/me/permissions/` and the rules for which Home tiles
/// to show (section 3 of the guide).
class PermissionSet {
  const PermissionSet(this.codes);

  const PermissionSet.empty() : codes = const [];

  final List<String> codes;

  bool get _everything => codes.contains('*');

  bool _has(String code) => _everything || codes.contains(code);

  bool _hasPrefix(String prefix) =>
      _everything || codes.any((c) => c.startsWith(prefix));

  bool get canSeePatients => _has('PATIENTS:SEARCH');
  bool get canViewPatientDetails => _has('PATIENTS:VIEW');
  bool get canSeeFacilities => _has('FACILITIES:VIEW');

  /// A role that can also edit has e.g. ORDERS:EDIT - any ORDERS: code counts.
  bool get canSeeOrders => _hasPrefix('ORDERS:');
  bool get canSeeResults => _has('RESULTS_VIEWER:VIEW');

  bool get hasAnyAccess =>
      canSeePatients || canSeeFacilities || canSeeOrders || canSeeResults;

  factory PermissionSet.fromJson(Map<String, dynamic> json) {
    return PermissionSet(
      Json.list(json['permissions']).map((e) => e.toString()).toList(),
    );
  }
}
