import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codemagic/core/providers/accounts_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('adding accounts makes the newest one active', () async {
    final prefs = await SharedPreferences.getInstance();
    final n = AccountsNotifier(prefs);
    await n.addAccount('token-a', 'A');
    await n.addAccount('token-b', 'B');
    expect(n.state.accounts, hasLength(2));
    expect(n.state.active!.name, 'B');
  });

  test('switching changes the active account', () async {
    final prefs = await SharedPreferences.getInstance();
    final n = AccountsNotifier(prefs);
    await n.addAccount('token-a', 'A');
    final aId = n.state.accounts.first.id;
    await n.addAccount('token-b', 'B');
    await n.switchAccount(aId);
    expect(n.state.active!.token, 'token-a');
  });

  test('removing the active account falls back to another', () async {
    final prefs = await SharedPreferences.getInstance();
    final n = AccountsNotifier(prefs);
    await n.addAccount('token-a', 'A');
    await n.addAccount('token-b', 'B');
    await n.removeAccount(n.state.activeId!);
    expect(n.state.accounts, hasLength(1));
    expect(n.state.active!.name, 'A');
  });

  test('removing the last account leaves none active', () async {
    final prefs = await SharedPreferences.getInstance();
    final n = AccountsNotifier(prefs);
    await n.addAccount('token-a', 'A');
    await n.removeAccount(n.state.activeId!);
    expect(n.state.accounts, isEmpty);
    expect(n.state.active, isNull);
  });

  test('renaming keeps the token and the active selection', () async {
    final prefs = await SharedPreferences.getInstance();
    final n = AccountsNotifier(prefs);
    await n.addAccount('token-a', 'A');
    final id = n.state.activeId!;
    await n.renameAccount(id, 'Work');
    expect(n.state.active!.name, 'Work');
    expect(n.state.active!.token, 'token-a');
  });

  test('a legacy single token is migrated into an account', () async {
    SharedPreferences.setMockInitialValues({'codemagic_api_token': 'old'});
    final prefs = await SharedPreferences.getInstance();
    final n = AccountsNotifier(prefs);
    expect(n.state.accounts, hasLength(1));
    expect(n.state.active!.token, 'old');
    expect(prefs.getString('codemagic_api_token'), isNull);
  });
}
