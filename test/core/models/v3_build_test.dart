import 'package:flutter_test/flutter_test.dart';
import 'package:codemagic/core/models/app_model.dart';

// Trimmed from a real GET /api/v3/teams/{id}/builds item.
final v3Item = {
  'id': '6a941a0014bf8ccd332f2844',
  'app_id': '6a93a352009dcdab34b3feff',
  'workflow': {
    'id': 'ios',
    'source': 'file',
    'name': 'Pheem · iOS (unsigned IPA)',
  },
  'status': 'finished',
  'index': 8,
  'artifacts': [
    {
      'name': 'pheem-unsigned.ipa',
      'size_in_bytes': 4970018,
      'type': 'ipa',
      'short_lived_download_url': 'https://api.codemagic.io//artifacts/.eJwV',
      'version_code': '108',
      'version_name': '1.0.108',
    },
  ],
  'labels': ['release', 'hotfix'],
  'release_notes': [],
  'created_at': '2026-08-30T11:54:40.088000Z',
  'commit': {
    'hash': 'c5f94176c1d9bdd52c30d13e4789fe2347e8a6d9',
    'avatar_url': 'https://avatars.githubusercontent.com/u/19328632?v=4',
    'author_name': 'huylv69',
    'message': 'Build iOS automatically on every push to master',
    'url': 'https://github.com/huylv69/pheem/commit/c5f9',
  },
  'branch': 'master',
  'tag': null,
  'pull_request': null,
  'started_at': '2026-08-30T11:54:47.042000Z',
  'finished_at': '2026-08-30T11:56:41.589000Z',
};

void main() {
  group('CmBuild.fromV3Json', () {
    test(
      'maps the snake_case shape onto the same model the app already uses',
      () {
        final b = CmBuild.fromV3Json(v3Item);
        expect(b.id, '6a941a0014bf8ccd332f2844');
        expect(b.appId, '6a93a352009dcdab34b3feff');
        expect(b.status, 'finished');
        expect(b.isSuccess, isTrue);
        expect(b.buildNumber, '8');
        expect(b.branch, 'master');
        expect(
          b.commitMessage,
          'Build iOS automatically on every push to master',
        );
        expect(b.commitHash, startsWith('c5f94176'));
        expect(b.startedAt, isNotNull);
        expect(b.duration!.inSeconds, 114);
      },
    );

    test(
      'resolves the workflow name legacy never gave for file-based apps',
      () {
        final b = CmBuild.fromV3Json(v3Item);
        expect(b.workflowName, 'Pheem · iOS (unsigned IPA)');
        expect(b.fileWorkflowId, 'ios');
        expect(b.workflowId, 'ios');
      },
    );

    test('carries the fields legacy does not have', () {
      final b = CmBuild.fromV3Json(v3Item);
      expect(b.labels, ['release', 'hotfix']);
      expect(b.authorName, 'huylv69');
      expect(b.authorAvatarUrl, contains('avatars.githubusercontent.com'));
      expect(b.commitUrl, contains('github.com/huylv69/pheem/commit'));
    });

    test('maps artifacts, using the short-lived url and no secure path', () {
      final a = CmBuild.fromV3Json(v3Item).artifacts.single;
      expect(a.name, 'pheem-unsigned.ipa');
      expect(a.size, 4970018);
      expect(a.versionName, '1.0.108');
      expect(a.url, startsWith('https://api.codemagic.io'));
      // The public-url endpoint needs the secure filename, which v3 omits; the
      // detail sheet must not think a short-lived link is one.
      expect(a.path, isNull);
    });

    test('a ui-configured workflow uses its id as the workflow id', () {
      final b = CmBuild.fromV3Json({
        ...v3Item,
        'workflow': {
          'id': '69db8896e8153d605329c4e8',
          'source': 'ui',
          'name': 'Default Workflow',
        },
      });
      expect(b.workflowId, '69db8896e8153d605329c4e8');
      expect(b.fileWorkflowId, isNull);
      expect(b.workflowName, 'Default Workflow');
    });
  });

  group('CmBuildAction.fromV3Json', () {
    test('reads the v3 action shape', () {
      final a = CmBuildAction.fromV3Json({
        'id': '6a93a35fdfb3317fb83f165b',
        'name': 'Preparing build machine',
        'type': 'preparing',
        'has_test_results': false,
        'script': null,
        'status': 'success',
        'started_at': '2026-08-30T03:28:39.031000Z',
        'finished_at': '2026-08-30T03:29:19.920000Z',
      });
      expect(a.id, '6a93a35fdfb3317fb83f165b');
      expect(a.isSuccess, isTrue);
      expect(a.duration!.inSeconds, 40);
    });
  });

  group('CmBuildPage', () {
    test('keeps the cursor so the next page can be asked for', () {
      final p = CmBuildPage.fromV3Json({
        'data': [v3Item],
        'page_size': 30,
        'cursor': '69e3a953c874f9f3f3a40677',
      });
      expect(p.builds, hasLength(1));
      expect(p.nextCursor, '69e3a953c874f9f3f3a40677');
      expect(p.hasMore, isTrue);
    });

    test('a null cursor means the list is exhausted', () {
      final p = CmBuildPage.fromV3Json({
        'data': [],
        'page_size': 30,
        'cursor': null,
      });
      expect(p.hasMore, isFalse);
    });
  });

  group('BuildsQuery', () {
    test('turns filters into the query params v3 accepts', () {
      const q = BuildsQuery(
        status: 'failed',
        branch: 'master',
        labels: ['release'],
      );
      expect(q.toParams(appId: 'a1', cursor: 'c9', pageSize: 20), {
        'app_id': 'a1',
        'status': 'failed',
        'branch': 'master',
        'label': 'release',
        'cursor': 'c9',
        'page_size': '20',
      });
    });

    test('omits what is not set instead of sending empty strings', () {
      expect(const BuildsQuery().toParams(appId: 'a1', pageSize: 30), {
        'app_id': 'a1',
        'page_size': '30',
      });
    });
  });
}
