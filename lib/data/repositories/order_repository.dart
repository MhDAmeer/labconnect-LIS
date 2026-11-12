import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/lab_result.dart';
import '../models/order.dart';

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  /// GET /orders/orders/ - not paged, newest first. A date range keeps it
  /// short, so the screen asks for the last weeks by default.
  Future<List<OrderSummary>> list({
    int? facilityId,
    OrderFilter filter = const OrderFilter(),
  }) async {
    final data = await _api.get('/orders/orders/', query: {
      'facility_id': facilityId?.toString() ?? '',
      'status': filter.status?.apiValue ?? '',
      'patient_id': filter.patientId?.toString() ?? '',
      'date_from':
          filter.dateFrom == null ? '' : _apiDate.format(filter.dateFrom!),
      'date_to': filter.dateTo == null ? '' : _apiDate.format(filter.dateTo!),
    });

    // Documented as a plain list; tolerate a paged object just in case.
    final rows = data is List ? data : Json.list(Json.map(data)['results']);
    return rows.map((e) => OrderSummary.fromJson(Json.map(e))).toList();
  }

  Future<OrderDetail> details(int orderId) async {
    final data = await _api.get('/orders/orders/$orderId/');
    return OrderDetail.fromJson(Json.map(data));
  }

  /// GET /orders/results-viewer/?search=&group=order
  ///
  /// `search` is required by the server (an order number, MRN or accession
  /// number); without it the answer is an empty list, so we don't call.
  Future<List<OrderResults>> results({
    required String search,
    int? facilityId,
  }) async {
    final term = search.trim();
    if (term.isEmpty) return const [];

    final data = await _api.get('/orders/results-viewer/', query: {
      'search': term,
      'group': 'order',
      'facility_id': facilityId?.toString() ?? '',
    });
    final rows = data is List ? data : Json.list(Json.map(data)['results']);
    return rows.map((e) => OrderResults.fromJson(Json.map(e))).toList();
  }

  /// GET /orders/orders/{id}/result-report.pdf
  ///
  /// With [forDownload] the server adds the ORD-...-result-report.pdf name.
  Future<DownloadedFile> reportPdf(
    int orderId, {
    bool forDownload = false,
  }) {
    return _api.getFile(
      '/orders/orders/$orderId/result-report.pdf',
      query: forDownload ? const {'download': '1'} : null,
    );
  }
}
