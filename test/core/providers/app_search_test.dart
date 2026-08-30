import 'package:flutter_test/flutter_test.dart';
import 'package:codemagic/core/models/app_model.dart';
import 'package:codemagic/core/providers/codemagic_provider.dart';

CmApplication _app(String name, {String? repo}) =>
    CmApplication(id: name, appName: name, repositoryUrl: repo);

void main() {
  final apps = [
    _app('ignite', repo: 'https://github.com/huylv69/ignite'),
    _app('monvy', repo: 'https://github.com/huylv69/monvy'),
    _app('pheem', repo: 'https://github.com/huylv69/pheem'),
  ];

  test('empty query returns everything', () {
    expect(filterApps(apps, ''), hasLength(3));
    expect(filterApps(apps, '   '), hasLength(3));
  });

  test('matches on app name, case-insensitively', () {
    expect(filterApps(apps, 'IGN').single.appName, 'ignite');
  });

  test('matches on repository url', () {
    expect(filterApps(apps, 'huylv69'), hasLength(3));
    expect(filterApps(apps, 'monvy').single.appName, 'monvy');
  });

  test('no match returns empty, not everything', () {
    expect(filterApps(apps, 'zzz'), isEmpty);
  });

  test('tolerates apps with no repository url', () {
    expect(filterApps([_app('solo')], 'solo'), hasLength(1));
    expect(filterApps([_app('solo')], 'github'), isEmpty);
  });
}
