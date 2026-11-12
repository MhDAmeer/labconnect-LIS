import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/patient.dart';

class PatientRepository {
  PatientRepository(this._api);

  final ApiClient _api;

  /// One page of search results, so a long list never loads in one go.
  /// Returns the patients and whether another page exists.
  Future<PatientPage> search({
    String search = '',
    int? facilityId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get('/patients/', query: {
      'search': search.trim(),
      'facility_id': facilityId?.toString() ?? '',
      'page': '$page',
      'page_size': '$pageSize',
    });

    if (data is List) {
      return PatientPage(
        patients: data.map((e) => Patient.fromJson(Json.map(e))).toList(),
        hasMore: false,
      );
    }
    final map = Json.map(data);
    return PatientPage(
      patients: Json.list(map['results'])
          .map((e) => Patient.fromJson(Json.map(e)))
          .toList(),
      hasMore: Json.string(map['next']) != null,
      total: Json.integer(map['count']),
    );
  }

  /// Opened by MRN, not by id.
  Future<Patient> byMrn(String mrn) async {
    final data = await _api.get('/patients/${Uri.encodeComponent(mrn)}/');
    return Patient.fromJson(Json.map(data));
  }
}

class PatientPage {
  const PatientPage({
    required this.patients,
    required this.hasMore,
    this.total,
  });

  final List<Patient> patients;
  final bool hasMore;
  final int? total;
}
