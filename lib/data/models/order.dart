import '../../core/utils/json_utils.dart';

/// The eight statuses the orders endpoint filters on.
enum OrderStatus {
  ordered('ORDERED', 'Ordered'),
  collected('COLLECTED', 'Collected'),
  inLab('IN_LAB', 'In lab'),
  inProgress('IN_PROGRESS', 'In progress'),
  resulted('RESULTED', 'Resulted'),
  verified('VERIFIED', 'Verified'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const OrderStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static OrderStatus? tryParse(String? value) {
    for (final status in OrderStatus.values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// Text for a raw status coming from the server, tolerant of unknown values.
String orderStatusLabel(String raw) {
  final known = OrderStatus.tryParse(raw);
  if (known != null) return known.label;
  if (raw.isEmpty) return '-';
  final spaced = raw.replaceAll('_', ' ').toLowerCase();
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// One row of `GET /orders/orders/`.
class OrderSummary {
  const OrderSummary({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    this.patientId,
    this.patientMrn,
    this.patientName,
    this.facilityId,
    this.facilityTimeZone,
    this.priorityName,
    this.physicianName,
    this.isPackage = false,
    this.orderedAt,
  });

  final int orderId;
  final String orderNumber;
  final String status;
  final int? patientId;
  final String? patientMrn;
  final String? patientName;
  final int? facilityId;
  final String? facilityTimeZone;
  final String? priorityName;
  final String? physicianName;
  final bool isPackage;
  final DateTime? orderedAt;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      orderId: Json.integer(json['order_id'] ?? json['id']) ?? 0,
      orderNumber: Json.text(json['order_number']),
      status: Json.text(json['status']),
      patientId: Json.integer(json['patient']),
      patientMrn: Json.string(json['patient_mrn']),
      patientName: Json.string(json['patient_name']),
      facilityId: Json.integer(json['facility']),
      facilityTimeZone: Json.string(json['facility_time_zone']),
      priorityName: Json.string(json['priority_name']),
      physicianName: Json.string(json['physician_name']),
      isPackage: Json.boolean(json['is_package']),
      orderedAt: Json.dateTime(json['ordered_at']),
    );
  }
}

class OrderTestLine {
  const OrderTestLine({
    required this.testName,
    this.specimenType,
    this.accessionNumber,
    this.status,
  });

  final String testName;
  final String? specimenType;
  final String? accessionNumber;
  final String? status;

  factory OrderTestLine.fromJson(Map<String, dynamic> json) {
    return OrderTestLine(
      testName: Json.nameOf(json['test_detail']) ??
          Json.string(json['test_name']) ??
          'Test',
      specimenType: Json.nameOf(json['specimen_type_detail']),
      accessionNumber: Json.string(json['accession_number']),
      status: Json.string(json['status']),
    );
  }
}

/// `GET /orders/orders/{order_id}/` - everything for the detail screen.
class OrderDetail {
  const OrderDetail({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    this.encounterCode,
    this.patientName,
    this.patientMrn,
    this.patientDob,
    this.patientGender,
    this.facilityName,
    this.facilityTimeZone,
    this.priorityName,
    this.physicianName,
    this.clinicalIndication,
    this.orderedAt,
    this.collectedAt,
    this.inLabAt,
    this.completedAt,
    this.accessions = const [],
    this.tests = const [],
  });

  final int orderId;
  final String orderNumber;
  final String status;
  final String? encounterCode;
  final String? patientName;
  final String? patientMrn;
  final String? patientDob;
  final String? patientGender;
  final String? facilityName;
  final String? facilityTimeZone;
  final String? priorityName;
  final String? physicianName;
  final String? clinicalIndication;
  final DateTime? orderedAt;
  final DateTime? collectedAt;
  final DateTime? inLabAt;
  final DateTime? completedAt;
  final List<String> accessions;
  final List<OrderTestLine> tests;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final patient = Json.map(json['patient_detail']);
    final facility = Json.map(json['facility_detail']);

    return OrderDetail(
      orderId: Json.integer(json['order_id'] ?? json['id']) ?? 0,
      orderNumber: Json.text(json['order_number']),
      status: Json.text(json['status']),
      encounterCode: Json.string(json['encounter_code']),
      patientName: Json.string(patient['name']),
      patientMrn: Json.string(patient['mrn']),
      patientDob: Json.string(patient['dob']),
      patientGender: Json.string(patient['gender']),
      facilityName: Json.nameOf(facility),
      facilityTimeZone: Json.string(json['facility_time_zone']) ??
          Json.string(facility['time_zone']) ??
          Json.string(facility['timezone']),
      priorityName: Json.nameOf(json['priority_detail']),
      physicianName: Json.nameOf(
        json['physician_detail'],
        keys: const ['full_name', 'name', 'display_name'],
      ),
      clinicalIndication: Json.string(json['clinical_indication']),
      orderedAt: Json.dateTime(json['ordered_at']),
      collectedAt: Json.dateTime(json['collected_at']),
      inLabAt: Json.dateTime(json['in_lab_at']),
      completedAt: Json.dateTime(json['completed_at']),
      accessions: Json.list(json['accessions'])
          .map((e) => e is Map ? Json.string(e['accession_number']) : Json.string(e))
          .whereType<String>()
          .toList(),
      tests: Json.list(json['order_tests'])
          .map((e) => OrderTestLine.fromJson(Json.map(e)))
          .toList(),
    );
  }
}

/// Filters for the orders list. Empty values are simply not sent.
class OrderFilter {
  const OrderFilter({this.status, this.dateFrom, this.dateTo, this.patientId});

  final OrderStatus? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? patientId;

  OrderFilter copyWith({
    OrderStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearStatus = false,
    bool clearDates = false,
  }) {
    return OrderFilter(
      status: clearStatus ? null : (status ?? this.status),
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      patientId: patientId,
    );
  }

  bool get isActive => status != null || dateFrom != null || dateTo != null;
}
