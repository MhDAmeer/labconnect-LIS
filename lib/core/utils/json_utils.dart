/// Small helpers for reading JSON without crashing when the server sends a
/// null, a number where we expected text, or leaves a field out.
class Json {
  const Json._();

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<dynamic> list(dynamic value) => value is List ? value : const [];

  static String? string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String text(dynamic value, [String fallback = '']) =>
      string(value) ?? fallback;

  static int? integer(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? decimal(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  static DateTime? dateTime(dynamic value) {
    final text = string(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }

  /// Best readable name out of a nested detail object such as
  /// `priority_detail` or `test_detail`, whose exact fields vary.
  static String? nameOf(dynamic value, {List<String> keys = _nameKeys}) {
    if (value is String) return string(value);
    if (value is Map) {
      for (final key in keys) {
        final found = string(value[key]);
        if (found != null) return found;
      }
    }
    return null;
  }

  static const List<String> _nameKeys = [
    'name',
    'test_name',
    'display_name',
    'description',
    'label',
    'code',
  ];
}
