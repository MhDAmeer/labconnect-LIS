import '../../core/utils/json_utils.dart';

/// Result flag: N normal, H high, L low, A abnormal, CH / CL critical.
enum ResultFlag {
  normal,
  high,
  low,
  abnormal,
  criticalHigh,
  criticalLow,
  none;

  static ResultFlag parse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'N':
        return ResultFlag.normal;
      case 'H':
        return ResultFlag.high;
      case 'L':
        return ResultFlag.low;
      case 'A':
        return ResultFlag.abnormal;
      case 'CH':
        return ResultFlag.criticalHigh;
      case 'CL':
        return ResultFlag.criticalLow;
      default:
        return ResultFlag.none;
    }
  }

  bool get isAbnormal =>
      this != ResultFlag.normal && this != ResultFlag.none;

  bool get isCritical =>
      this == ResultFlag.criticalHigh || this == ResultFlag.criticalLow;

  String get label {
    switch (this) {
      case ResultFlag.normal:
        return 'Normal';
      case ResultFlag.high:
        return 'High';
      case ResultFlag.low:
        return 'Low';
      case ResultFlag.abnormal:
        return 'Abnormal';
      case ResultFlag.criticalHigh:
        return 'Critical high';
      case ResultFlag.criticalLow:
        return 'Critical low';
      case ResultFlag.none:
        return '';
    }
  }
}

class LabResult {
  const LabResult({
    required this.resultId,
    required this.testName,
    this.batteryName,
    this.valueNumeric,
    this.valueText,
    this.unit,
    this.rangeLow,
    this.rangeHigh,
    this.flag = ResultFlag.none,
    this.isVerified = false,
    this.verifiedAt,
    this.comments,
  });

  final int resultId;
  final String testName;
  final String? batteryName;
  final String? valueNumeric;
  final String? valueText;
  final String? unit;
  final String? rangeLow;
  final String? rangeHigh;
  final ResultFlag flag;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? comments;

  /// Results that are not verified yet are shown as "Pending", never as a
  /// final value (guide, section 8).
  bool get isPending => !isVerified;

  /// The value to print: numeric rounded to 2 decimals, otherwise the text.
  String get displayValue {
    if (isPending) return 'Pending';
    final number = Json.decimal(valueNumeric);
    if (number != null) return number.toStringAsFixed(2);
    return valueText ?? '-';
  }

  /// "0.40 - 4.00" style range, or null when the server sent none.
  String? get displayRange {
    final low = Json.decimal(rangeLow);
    final high = Json.decimal(rangeHigh);
    if (low != null && high != null) {
      return '${low.toStringAsFixed(2)} - ${high.toStringAsFixed(2)}';
    }
    if (low != null) return '≥ ${low.toStringAsFixed(2)}';
    if (high != null) return '≤ ${high.toStringAsFixed(2)}';
    return null;
  }

  factory LabResult.fromJson(Map<String, dynamic> json) {
    return LabResult(
      resultId: Json.integer(json['result_id'] ?? json['id']) ?? 0,
      testName: Json.text(json['test_name'], 'Test'),
      batteryName: Json.string(json['battery_name']),
      valueNumeric: Json.string(json['value_numeric']),
      valueText: Json.string(json['value_text']),
      unit: Json.string(json['unit']),
      rangeLow: Json.string(json['range_low']),
      rangeHigh: Json.string(json['range_high']),
      flag: ResultFlag.parse(Json.string(json['flag'])),
      isVerified: Json.boolean(json['is_verified']),
      verifiedAt: Json.dateTime(json['verified_at']),
      comments: Json.string(json['comments']),
    );
  }
}

class PatientBanner {
  const PatientBanner({this.mrn, this.name, this.dob, this.gender});

  final String? mrn;
  final String? name;
  final String? dob;
  final String? gender;

  factory PatientBanner.fromJson(Map<String, dynamic> json) {
    return PatientBanner(
      mrn: Json.string(json['mrn']),
      name: Json.string(json['name']),
      dob: Json.string(json['dob']),
      gender: Json.string(json['gender']),
    );
  }
}

/// One entry of `GET /orders/results-viewer/?group=order`.
class OrderResults {
  const OrderResults({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.patient,
    required this.results,
    this.orderedAt,
    this.facilityTimeZone,
    this.encounterCode,
    this.accessions = const [],
  });

  final int orderId;
  final String orderNumber;
  final String status;
  final DateTime? orderedAt;
  final String? facilityTimeZone;
  final String? encounterCode;
  final List<String> accessions;
  final PatientBanner patient;
  final List<LabResult> results;

  int get abnormalCount =>
      results.where((r) => !r.isPending && r.flag.isAbnormal).length;

  int get normalCount =>
      results.where((r) => !r.isPending && !r.flag.isAbnormal).length;

  factory OrderResults.fromJson(Map<String, dynamic> json) {
    return OrderResults(
      orderId: Json.integer(json['order_id']) ?? 0,
      orderNumber: Json.text(json['order_number']),
      status: Json.text(json['status']),
      orderedAt: Json.dateTime(json['ordered_at']),
      facilityTimeZone: Json.string(json['facility_time_zone']),
      encounterCode: Json.string(json['encounter_code']),
      accessions: Json.list(json['accessions'])
          .map((e) => e is Map ? Json.string(e['accession_number']) : Json.string(e))
          .whereType<String>()
          .toList(),
      patient: PatientBanner.fromJson(Json.map(json['patient_detail'])),
      results: Json.list(json['results'])
          .map((e) => LabResult.fromJson(Json.map(e)))
          .toList(),
    );
  }
}
