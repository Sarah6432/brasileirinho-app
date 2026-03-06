import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Modelo para uma sessão de usuário salva.
class Session {
  final String login;
  final String token;

  Session({required this.login, required this.token});

  Map<String, dynamic> toJson() => {'login': login, 'token': token};

  factory Session.fromJson(Map<String, dynamic> json) =>
      Session(login: json['login'] as String, token: json['token'] as String);
}

/// Gerenciador global de autenticação multi-conta.
///
/// Singleton que mantém as sessões salvas e a sessão ativa,
/// utilizando [FlutterSecureStorage] para persistência segura.
class AuthManager extends ChangeNotifier {
  static final AuthManager instance = AuthManager._();

  AuthManager._();

  static const _storageKey = 'saved_accounts';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<Session> savedAccounts = [];
  Session? currentSession;

  /// Carrega as contas salvas do storage seguro.
  Future<void> loadAccounts() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      savedAccounts = decoded
          .map((e) => Session.fromJson(e as Map<String, dynamic>))
          .toList();
      if (savedAccounts.isNotEmpty) {
        currentSession = savedAccounts.first;
      }
    }
    notifyListeners();
  }

  /// Adiciona (ou atualiza) uma conta e a define como ativa.
  Future<void> addAccount(String login, String token) async {
    // Remove a sessão anterior do mesmo login (se existir) para atualizar o token
    savedAccounts.removeWhere((s) => s.login == login);
    final session = Session(login: login, token: token);
    savedAccounts.insert(0, session);
    currentSession = session;
    await _persist();
    notifyListeners();
  }

  /// Troca para a conta com o [login] informado.
  Future<void> switchAccount(String login) async {
    final session = savedAccounts.firstWhere((s) => s.login == login);
    currentSession = session;
    // Move a conta ativa para o topo da lista
    savedAccounts.remove(session);
    savedAccounts.insert(0, session);
    await _persist();
    notifyListeners();
  }

  /// Remove a conta ativa e troca para a próxima (se houver).
  Future<void> logout() async {
    if (currentSession == null) return;
    savedAccounts.removeWhere((s) => s.login == currentSession!.login);
    currentSession = savedAccounts.isNotEmpty ? savedAccounts.first : null;
    await _persist();
    notifyListeners();
  }

  /// Persiste a lista de contas no storage seguro.
  Future<void> _persist() async {
    final jsonList = savedAccounts.map((s) => s.toJson()).toList();
    await _storage.write(key: _storageKey, value: jsonEncode(jsonList));
  }
}
