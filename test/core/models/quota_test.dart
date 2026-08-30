import 'package:flutter_test/flutter_test.dart';
import 'package:codemagic/core/models/app_model.dart';

void main() {
  // Trimmed from a real GET /user response.
  final live = {
    'user': {
      'billing': {
        'usage': {
          'currentPeriod': {
            'buildTime': {
              'mac_mini_m2_free': 1258,
              'linux_x2_paid': 0,
              'windows_x2_paid': 0,
            },
          },
          'freeLimit': {'buildTime': 30000, 'concurrency': 1},
        },
      },
      'buildTimes': {
        'monthlyFreeBuildTimeLimit': 30000,
        'currentPeriod': {'free': 1258},
        'previousPeriod': {'free': 0},
      },
    },
  };

  test('reads the numbers the live API actually returns', () {
    final q = CmQuota.fromUserJson(live);
    expect(q.usedSeconds, 1258);
    expect(q.limitSeconds, 30000);
    expect(q.concurrency, 1);
    expect(q.remainingSeconds, 28742);
  });

  test('drops machine types that consumed nothing', () {
    final q = CmQuota.fromUserJson(live);
    expect(q.byInstanceType, {'mac_mini_m2_free': 1258});
  });

  test('fraction is a usable 0..1', () {
    expect(CmQuota.fromUserJson(live).fraction, closeTo(1258 / 30000, 1e-9));
  });

  test('an account with no free limit does not divide by zero', () {
    final q = CmQuota.fromUserJson({'user': {}});
    expect(q.hasLimit, isFalse);
    expect(q.fraction, 0);
    expect(q.remainingSeconds, 0);
  });

  test('overspending clamps instead of going negative', () {
    final q = CmQuota.fromUserJson({
      'user': {
        'buildTimes': {
          'monthlyFreeBuildTimeLimit': 100,
          'currentPeriod': {'free': 250},
        },
      },
    });
    expect(q.remainingSeconds, 0);
    expect(q.fraction, 1.0);
  });

  test('falls back to freeLimit when monthlyFreeBuildTimeLimit is absent', () {
    final q = CmQuota.fromUserJson({
      'user': {
        'buildTimes': {'currentPeriod': {'free': 60}},
        'billing': {
          'usage': {'freeLimit': {'buildTime': 600}},
        },
      },
    });
    expect(q.limitSeconds, 600);
    expect(q.remainingSeconds, 540);
  });
}
