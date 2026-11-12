import 'package:intl/intl.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class Formatters {
  const Formatters._();

  static bool _tzReady = false;

  /// Loads the time zone database once (call from main()).
  static void init() {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    _tzReady = true;
  }

  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy hh:mm a');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');

  /// Server times are UTC. Show them in the facility's own time zone, and
  /// fall back to the phone's zone if the name isn't known.
  static String dateTime(DateTime? utc, {String? zone}) {
    if (utc == null) return '-';
    return _dateTime.format(_inZone(utc, zone));
  }

  static String dateOnly(DateTime? utc, {String? zone}) {
    if (utc == null) return '-';
    return _date.format(_inZone(utc, zone));
  }

  static DateTime _inZone(DateTime utc, String? zone) {
    final moment = utc.isUtc ? utc : utc.toUtc();
    if (zone != null && zone.isNotEmpty && _tzReady) {
      try {
        final converted = tz.TZDateTime.from(moment, tz.getLocation(zone));
        // Plain DateTime with the zone's wall-clock fields, ready for intl.
        return DateTime(
          converted.year,
          converted.month,
          converted.day,
          converted.hour,
          converted.minute,
          converted.second,
        );
      } catch (_) {
        // Unknown zone name - use the phone's zone below.
      }
    }
    return moment.toLocal();
  }

  /// "YYYY-MM-DD" from the API to "dd/MM/yyyy" for the screen.
  static String birthDate(String? iso) {
    final parsed = iso == null ? null : DateTime.tryParse(iso);
    if (parsed == null) return iso == null || iso.isEmpty ? '-' : iso;
    return _date.format(parsed);
  }

  static int? ageFrom(String? iso, {DateTime? today}) {
    final dob = iso == null ? null : DateTime.tryParse(iso);
    if (dob == null) return null;
    final now = today ?? DateTime.now();
    var years = now.year - dob.year;
    final hadBirthday = now.month > dob.month ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) years--;
    return years < 0 ? null : years;
  }

  static String gender(String? code) {
    switch (code?.toUpperCase()) {
      case 'M':
        return 'Male';
      case 'F':
        return 'Female';
      case 'O':
        return 'Other';
      case 'U':
        return 'Unknown';
      default:
        return code == null || code.isEmpty ? '-' : code;
    }
  }

  /// For dates the user picked on the phone (already local - no zone shift).
  static String pickedDate(DateTime date) => _date.format(date);

  static String apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}
