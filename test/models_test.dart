import 'package:flutter_test/flutter_test.dart';
import 'package:labconnect_admin/core/utils/formatters.dart';
import 'package:labconnect_admin/data/models/auth_models.dart';
import 'package:labconnect_admin/data/models/lab_result.dart';
import 'package:labconnect_admin/data/models/order.dart';

void main() {
  group('PermissionSet (guide section 3)', () {
    test('a star shows every tile', () {
      const p = PermissionSet(['*']);
      expect(p.canSeePatients, isTrue);
      expect(p.canSeeFacilities, isTrue);
      expect(p.canSeeOrders, isTrue);
      expect(p.canSeeResults, isTrue);
    });

    test('each tile follows its own code', () {
      const p = PermissionSet(['PATIENTS:SEARCH', 'RESULTS_VIEWER:VIEW']);
      expect(p.canSeePatients, isTrue);
      expect(p.canSeeResults, isTrue);
      expect(p.canSeeFacilities, isFalse);
      expect(p.canSeeOrders, isFalse);
    });

    test('any ORDERS: code counts for the Orders tile', () {
      expect(const PermissionSet(['ORDERS:EDIT']).canSeeOrders, isTrue);
    });

    test('no codes means no access at all', () {
      expect(const PermissionSet([]).hasAnyAccess, isFalse);
    });
  });

  group('LabResult display (guide section 8)', () {
    LabResult make({
      String? numeric,
      String? text,
      bool verified = true,
      String flag = 'N',
    }) {
      return LabResult.fromJson({
        'result_id': 1,
        'test_name': 'TSH',
        'value_numeric': numeric,
        'value_text': text,
        'is_verified': verified,
        'flag': flag,
        'range_low': '0.400000',
        'range_high': '4.000000',
      });
    }

    test('numeric values are rounded to 2 decimals', () {
      expect(make(numeric: '4.000000').displayValue, '4.00');
      expect(make(numeric: '103').displayValue, '103.00');
    });

    test('text is used when there is no number', () {
      expect(make(text: 'Positive').displayValue, 'Positive');
    });

    test('unverified results are Pending, never a value', () {
      final r = make(numeric: '9.9', verified: false);
      expect(r.isPending, isTrue);
      expect(r.displayValue, 'Pending');
    });

    test('flags map to normal / abnormal', () {
      expect(make(numeric: '1', flag: 'N').flag.isAbnormal, isFalse);
      expect(make(numeric: '1', flag: 'H').flag.isAbnormal, isTrue);
      expect(make(numeric: '1', flag: 'CL').flag.isCritical, isTrue);
    });

    test('range text', () {
      expect(make(numeric: '1').displayRange, '0.40 - 4.00');
    });
  });

  group('Orders', () {
    test('summary reads the documented fields', () {
      final o = OrderSummary.fromJson({
        'order_id': 45,
        'order_number': 'ORD-1',
        'patient': 12,
        'patient_mrn': 'MRN-0001',
        'patient_name': 'Jane Doe',
        'status': 'VERIFIED',
        'ordered_at': '2026-11-05T05:40:01Z',
        'facility_time_zone': 'Asia/Dubai',
      });
      expect(o.orderId, 45);
      expect(o.patientId, 12);
      expect(o.orderedAt!.isUtc, isTrue);
    });

    test('unknown status still gets a readable label', () {
      expect(orderStatusLabel('IN_LAB'), 'In lab');
      expect(orderStatusLabel('SOMETHING_NEW'), 'Something new');
    });
  });

  group('Formatters', () {
    setUpAll(Formatters.init);

    test('UTC time is shown in the facility zone', () {
      final utc = DateTime.utc(2026, 11, 5, 5, 40);
      // Dubai is UTC+4 all year.
      expect(
        Formatters.dateTime(utc, zone: 'Asia/Dubai'),
        '05/11/2026 09:40 AM',
      );
    });

    test('age counts birthdays', () {
      final today = DateTime(2026, 11, 10);
      expect(Formatters.ageFrom('1990-11-10', today: today), 36);
      expect(Formatters.ageFrom('1990-11-11', today: today), 35);
      expect(Formatters.ageFrom('nonsense', today: today), isNull);
    });
  });
}
