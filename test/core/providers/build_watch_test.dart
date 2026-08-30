import 'package:flutter_test/flutter_test.dart';
import 'package:codemagic/core/models/app_model.dart';
import 'package:codemagic/core/providers/build_watch_provider.dart';

CmBuild _b(String id, String status) => CmBuild(
  id: id,
  appId: 'a',
  workflowId: 'w',
  workflowName: 'W',
  status: status,
);

void main() {
  test('a build seen running that is now finished is reported', () {
    final out = detectFinished({'1'}, [_b('1', 'finished')]);
    expect(out.map((b) => b.id), ['1']);
  });

  test('failed and canceled count as finished too', () {
    final out = detectFinished(
      {'1', '2'},
      [_b('1', 'failed'), _b('2', 'canceled')],
    );
    expect(out, hasLength(2));
  });

  test('a build still running is not reported', () {
    expect(detectFinished({'1'}, [_b('1', 'building')]), isEmpty);
  });

  test('builds that were already done when we first looked are ignored', () {
    // Nothing was running before, so nothing can have *finished* since —
    // this is what stops the app announcing old results on launch.
    expect(
      detectFinished({}, [_b('1', 'finished'), _b('2', 'failed')]),
      isEmpty,
    );
  });

  test('a build that fell off the recent list is simply forgotten', () {
    expect(detectFinished({'gone'}, [_b('1', 'finished')]), isEmpty);
  });

  test('runningIds picks out preparing, building and publishing', () {
    final ids = runningIds([
      _b('1', 'preparing'),
      _b('2', 'building'),
      _b('3', 'publishing'),
      _b('4', 'finished'),
      _b('5', 'queued'),
    ]);
    expect(ids, {'1', '2', '3'});
  });
}
