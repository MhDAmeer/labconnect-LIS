import '../../core/utils/json_utils.dart';

class PatientDemographics {
  const PatientDemographics({
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.dob,
    this.gender,
    this.mobile,
    this.email,
    this.nationality,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final String? dob; // kept as YYYY-MM-DD text, exactly as the server sends it
  final String? gender;
  final String? mobile;
  final String? email;
  final String? nationality;

  factory PatientDemographics.fromJson(Map<String, dynamic> json) {
    return PatientDemographics(
      firstName: Json.text(json['first_name']),
      middleName: Json.text(json['middle_name']),
      lastName: Json.text(json['last_name']),
      dob: Json.string(json['dob']),
      gender: Json.string(json['gender']),
      mobile: Json.string(json['mobile']),
      email: Json.string(json['email']),
      nationality: Json.string(json['nationality']),
    );
  }
}

/// Insurance and next of kin are only listed on the details screen. The guide
/// doesn't spell out their fields, so each entry is reduced to a title and an
/// optional second line.
class PatientNote {
  const PatientNote({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  static PatientNote? insurance(Map<String, dynamic> json) {
    final title = Json.nameOf(json, keys: const [
      'insurance_company_name',
      'provider_name',
      'insurance_name',
      'company_name',
      'payer_name',
      'name',
    ]);
    if (title == null) return null;
    final policy = Json.string(json['policy_number'] ?? json['member_id']);
    return PatientNote(
      title: title,
      subtitle: policy == null ? null : 'Policy $policy',
    );
  }

  static PatientNote? nextOfKin(Map<String, dynamic> json) {
    final direct = Json.string(json['name']);
    final joined = [json['first_name'], json['last_name']]
        .map(Json.string)
        .whereType<String>()
        .join(' ');
    final title = direct ?? (joined.isEmpty ? null : joined);
    if (title == null) return null;

    final parts = [
      Json.string(json['relationship']),
      Json.string(json['mobile'] ?? json['phone']),
    ].whereType<String>().toList();
    return PatientNote(
      title: title,
      subtitle: parts.isEmpty ? null : parts.join(' · '),
    );
  }
}

class Patient {
  const Patient({
    required this.id,
    required this.mrn,
    required this.demographics,
    this.facilityId,
    this.facilityName,
    this.registrationType,
    this.isActive = true,
    this.insurances = const [],
    this.nextOfKin = const [],
  });

  final int id;
  final String mrn;
  final int? facilityId;
  final String? facilityName;
  final String? registrationType;
  final bool isActive;
  final PatientDemographics demographics;
  final List<PatientNote> insurances;
  final List<PatientNote> nextOfKin;

  String get fullName {
    final d = demographics;
    final name = [d.firstName, d.middleName, d.lastName]
        .where((e) => e.isNotEmpty)
        .join(' ');
    return name.isEmpty ? mrn : name;
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: Json.integer(json['id']) ?? 0,
      mrn: Json.text(json['mrn']),
      facilityId: Json.integer(json['facility_id']),
      facilityName: Json.string(json['facility_name']),
      registrationType: Json.string(json['registration_type']),
      isActive: Json.boolean(json['is_active'], fallback: true),
      demographics: PatientDemographics.fromJson(Json.map(json['demographics'])),
      insurances: Json.list(json['insurances'])
          .map((e) => PatientNote.insurance(Json.map(e)))
          .whereType<PatientNote>()
          .toList(),
      nextOfKin: Json.list(json['next_of_kin'])
          .map((e) => PatientNote.nextOfKin(Json.map(e)))
          .whereType<PatientNote>()
          .toList(),
    );
  }
}
