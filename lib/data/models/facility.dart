import '../../core/utils/json_utils.dart';

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.code,
    this.facilityType,
    this.prefix,
    this.isActive = true,
    this.isDefault = false,
    this.groupName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.zipCode,
    this.phoneNumber,
    this.faxNumber,
  });

  final int id;
  final String name;
  final String code;
  final String? facilityType;
  final String? prefix;
  final bool isActive;
  final bool isDefault;
  final String? groupName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? phoneNumber;
  final String? faxNumber;

  /// Address as separate printable lines, skipping the empty parts.
  List<String> get addressLines {
    final cityLine = [city, state, zipCode]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');
    return [addressLine1, addressLine2, cityLine]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: Json.integer(json['id']) ?? 0,
      name: Json.text(json['name']),
      code: Json.text(json['code']),
      facilityType: Json.string(json['facility_type']),
      prefix: Json.string(json['prefix']),
      isActive: Json.boolean(json['is_active'], fallback: true),
      isDefault: Json.boolean(json['is_default']),
      groupName: Json.string(json['group_name']),
      addressLine1: Json.string(json['address_line1']),
      addressLine2: Json.string(json['address_line2']),
      city: Json.string(json['city']),
      state: Json.string(json['state']),
      zipCode: Json.string(json['zip_code']),
      phoneNumber: Json.string(json['phone_number']),
      faxNumber: Json.string(json['fax_number']),
    );
  }
}
