import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/facility.dart';

class FacilityRepository {
  FacilityRepository(this._api);

  final ApiClient _api;

  Future<List<Facility>> list({String search = ''}) async {
    final rows = await _api.getAllPages(
      '/facilities/',
      query: {'search': search.trim(), 'ordering': 'name'},
    );
    return rows.map((e) => Facility.fromJson(Json.map(e))).toList();
  }

  Future<Facility> details(int id) async {
    final data = await _api.get('/facilities/$id/');
    return Facility.fromJson(Json.map(data));
  }
}
