import 'package:flutter_test/flutter_test.dart';
import 'package:codemagic/presentation/widgets/account_sheet.dart';

void main() {
  group('quotaMinutes', () {
    test('counts in the unit Codemagic sells the plan in', () {
      // 30000s is the free monthly allowance. Codemagic calls it 500 minutes;
      // rendering it as "8h 20m" made the reader convert it back by hand.
      expect(quotaMinutes(30000), '500');
      expect(quotaMinutes(1258), '20');
    });

    test('floors, so a machine breakdown never overstates what it burned', () {
      expect(quotaMinutes(59), '0');
      expect(quotaMinutes(119), '1');
    });
  });

  group('quotaMachineLabel', () {
    test('says the machine in words and drops the free bucket', () {
      expect(quotaMachineLabel('mac_mini_m2_free'), 'Mac mini M2');
      expect(quotaMachineLabel('linux_x2_free'), 'Linux x2');
    });

    test('keeps a bucket worth knowing about', () {
      expect(quotaMachineLabel('mac_mini_m4_paid'), 'Mac mini M4 (paid)');
      expect(quotaMachineLabel('windows_x2_personal'), 'Windows x2 (personal)');
    });

    test('an unknown machine degrades to something readable', () {
      expect(quotaMachineLabel('some_new_box_free'), 'some new box');
    });
  });
}
