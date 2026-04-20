import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_model.dart';
import 'auth_provider.dart';

const _accountsKey = 'ignite_accounts';
const _activeIdKey = 'ignite_active_account_id';
const _legacyTokenKey = 'codemagic_api_token';

class AccountsState {
  final List<AccountModel> accounts;
  final String? activeId;

  const AccountsState({this.accounts = const [], this.activeId});

  AccountModel? get active =>
      accounts.isEmpty ? null : accounts.firstWhere((a) => a.id == activeId, orElse: () => accounts.first);

  AccountsState copyWith({List<AccountModel>? accounts, String? activeId}) =>
      AccountsState(accounts: accounts ?? this.accounts, activeId: activeId ?? this.activeId);
}

class AccountsNotifier extends StateNotifier<AccountsState> {
  final SharedPreferences _prefs;

  AccountsNotifier(this._prefs) : super(const AccountsState()) {
    _load();
  }

  void _load() {
    var accounts = AccountModel.listFromJson(_prefs.getString(_accountsKey) ?? '[]');

    // Migrate legacy single token
    final legacy = _prefs.getString(_legacyTokenKey);
    if (legacy != null && legacy.isNotEmpty && accounts.isEmpty) {
      final migrated = AccountModel(id: _newId(), name: 'Default', token: legacy);
      accounts = [migrated];
      _persist(accounts, migrated.id);
      _prefs.remove(_legacyTokenKey);
    }

    final activeId = _prefs.getString(_activeIdKey) ?? accounts.firstOrNull?.id;
    state = AccountsState(accounts: accounts, activeId: activeId);
  }

  Future<void> addAccount(String token, String name) async {
    final account = AccountModel(id: _newId(), name: name, token: token);
    final updated = [...state.accounts, account];
    _persist(updated, account.id);
    state = AccountsState(accounts: updated, activeId: account.id);
  }

  Future<void> switchAccount(String id) async {
    await _prefs.setString(_activeIdKey, id);
    state = state.copyWith(activeId: id);
  }

  Future<void> removeAccount(String id) async {
    final updated = state.accounts.where((a) => a.id != id).toList();
    final newActiveId = state.activeId == id ? updated.firstOrNull?.id : state.activeId;
    _persist(updated, newActiveId);
    state = AccountsState(accounts: updated, activeId: newActiveId);
  }

  Future<void> logoutActive() => removeAccount(state.activeId ?? '');

  Future<void> renameAccount(String id, String name) async {
    final updated = state.accounts.map((a) => a.id == id ? a.copyWith(name: name) : a).toList();
    _persist(updated, state.activeId);
    state = state.copyWith(accounts: updated);
  }

  void _persist(List<AccountModel> accounts, String? activeId) {
    _prefs.setString(_accountsKey, AccountModel.listToJson(accounts));
    if (activeId != null) _prefs.setString(_activeIdKey, activeId);
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${state.accounts.length}';
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, AccountsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountsNotifier(prefs);
});

// Keep authProvider compatible — returns active token
final activeTokenProvider = Provider<String?>((ref) {
  return ref.watch(accountsProvider).active?.token;
});
