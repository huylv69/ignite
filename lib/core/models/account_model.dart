import 'dart:convert';

class AccountModel {
  final String id;
  final String name;
  final String token;

  const AccountModel({required this.id, required this.name, required this.token});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'token': token};

  factory AccountModel.fromJson(Map<String, dynamic> j) => AccountModel(
        id: j['id'] as String,
        name: j['name'] as String,
        token: j['token'] as String,
      );

  static List<AccountModel> listFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => AccountModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<AccountModel> accounts) =>
      jsonEncode(accounts.map((a) => a.toJson()).toList());

  AccountModel copyWith({String? name}) =>
      AccountModel(id: id, name: name ?? this.name, token: token);
}
