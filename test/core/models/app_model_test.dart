import 'package:flutter_test/flutter_test.dart';
import 'package:codemagic/core/models/app_model.dart';

void main() {
  group('CmBuildAction', () {
    test('parses the shape the API actually returns', () {
      final a = CmBuildAction.fromJson({
        '_id': '69e6466155edef45ebb8335d',
        'name': 'Get Flutter packages',
        'status': 'success',
        'startedAt': '2026-04-20T15:31:02.193000+00:00',
        'finishedAt': '2026-04-20T15:31:18.982000+00:00',
      });
      expect(a.id, '69e6466155edef45ebb8335d');
      expect(a.name, 'Get Flutter packages');
      expect(a.isSuccess, isTrue);
      expect(a.duration!.inSeconds, 16);
    });

    test('treats skipped and canceled as distinct from failed', () {
      expect(CmBuildAction.fromJson({'status': 'skipped'}).isSkipped, isTrue);
      expect(CmBuildAction.fromJson({'status': 'skipped'}).isFailed, isFalse);
      expect(CmBuildAction.fromJson({'status': 'canceled'}).isCanceled, isTrue);
    });
  });

  group('CmArtifact', () {
    test('keeps path as the secure filename for public-url', () {
      final a = CmArtifact.fromJson({
        'name': 'unsigned_ignite.ipa',
        'type': 'ipa',
        'url':
            'https://api.codemagic.io/artifacts/a0f0/c3f0/unsigned_ignite.ipa',
        'size': 7582792,
        'versionName': '1.0.0',
        'path': 'a0f0/c3f0/unsigned_ignite.ipa',
      });
      expect(a.path, 'a0f0/c3f0/unsigned_ignite.ipa');
      expect(a.versionName, '1.0.0');
    });

    test('falls back to deriving path from the url when absent', () {
      final a = CmArtifact.fromJson({
        'name': 'app.apk',
        'url': 'https://api.codemagic.io/artifacts/aaa/bbb/app.apk',
      });
      expect(a.path, 'aaa/bbb/app.apk');
    });
  });

  group('CmCache', () {
    test('parses a cache entry', () {
      final c = CmCache.fromJson({
        '_id': 'c1',
        'appId': 'a1',
        'workflowId': 'ios-workflow',
        'size': 1048576,
        'lastUsed': '2026-08-30T03:28:38.751000+00:00',
      });
      expect(c.id, 'c1');
      expect(c.workflowId, 'ios-workflow');
      expect(c.size, 1048576);
      expect(c.lastUsed, isNotNull);
    });
  });

  group('CmVariable', () {
    test('round-trips through json', () {
      final v = CmVariable.fromJson({
        'id': 'v1',
        'key': 'VERCEL_TOKEN',
        'value': '********',
        'group': 'env_vars',
        'secure': true,
      });
      expect(v.key, 'VERCEL_TOKEN');
      expect(v.secure, isTrue);
      expect(v.toJson()['group'], 'env_vars');
    });
  });

  group('CmBuild', () {
    test('reads buildActions and instanceType', () {
      final b = CmBuild.fromJson({
        '_id': 'b1',
        'appId': 'a1',
        'status': 'finished',
        'instanceType': 'mac_mini_m2',
        'fileWorkflowId': 'ios-workflow',
        'buildActions': [
          {'_id': 's1', 'name': 'Preparing build machine', 'status': 'success'},
          {'_id': 's2', 'name': 'Flutter build iOS', 'status': 'success'},
        ],
      });
      expect(b.buildActions, hasLength(2));
      expect(b.buildActions.first.name, 'Preparing build machine');
      expect(b.instanceType, 'mac_mini_m2');
    });
  });
}
