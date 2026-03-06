import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:brasileirinho/features/service/auth_manager.dart';

/// Exceção personalizada da API com mensagens amigáveis em PT-BR.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;

  /// Traduz erros comuns da API para PT-BR legível.
  static String _translateError(String field, String error) {
    final fieldName = _fieldNames[field] ?? field;
    final translated = _errorTranslations.entries
        .where((e) => error.contains(e.key))
        .map((e) => e.value)
        .firstOrNull;

    if (translated != null) {
      return '$fieldName $translated';
    }
    return '$fieldName: $error';
  }

  static const _fieldNames = {
    'login': 'Login',
    'name': 'Nome',
    'password': 'Senha',
    'password_confirmation': 'Confirmação de senha',
    'message': 'Mensagem',
    'email': 'E-mail',
    'base': '',
  };

  static const _errorTranslations = {
    'has already been taken': 'já está em uso',
    'is too short': 'é muito curto(a)',
    'is too long': 'é muito longo(a)',
    'can\'t be blank': 'não pode ficar vazio(a)',
    'is invalid': 'é inválido(a)',
    'doesn\'t match': 'não confere',
    'not found': 'não encontrado(a)',
    'is not included': 'valor não permitido',
  };

  /// Converte o body de erro da API em uma mensagem legível.
  /// [isLoginAttempt] evita redirecionar ao login quando o 401 vem da própria tentativa de login.
  static ApiException fromResponse(
    int statusCode,
    dynamic body, {
    bool isLoginAttempt = false,
  }) {
    // Token expirado — redireciona ao login (exceto durante tentativa de login)
    if (statusCode == 401 && !isLoginAttempt) {
      AuthManager.instance.handleSessionExpired();
      return ApiException(
        'Sessão expirada. Faça login novamente.',
        statusCode: statusCode,
      );
    }

    // Caso especial: login inválido
    if (statusCode == 401) {
      return ApiException('Login ou senha inválidos.', statusCode: statusCode);
    }

    if (body is Map) {
      // Formato: {"errors": {"login": ["has already been taken"]}}
      final errors = body['errors'];
      if (errors is Map) {
        final messages = <String>[];
        errors.forEach((field, fieldErrors) {
          if (fieldErrors is List) {
            for (final e in fieldErrors) {
              messages.add(_translateError(field.toString(), e.toString()));
            }
          } else {
            messages.add(
              _translateError(field.toString(), fieldErrors.toString()),
            );
          }
        });
        if (messages.isNotEmpty) {
          return ApiException(messages.join('\n'), statusCode: statusCode);
        }
      }

      // Formato: {"errors": "mensagem simples"} ou {"error": "..."}
      if (errors is String) {
        return ApiException(errors, statusCode: statusCode);
      }
      final error = body['error'];
      if (error is String) {
        return ApiException(error, statusCode: statusCode);
      }

      // Formato: {"message": "..."}
      final message = body['message'];
      if (message is String) {
        return ApiException(message, statusCode: statusCode);
      }
    }

    if (body is String && body.isNotEmpty) {
      return ApiException(body, statusCode: statusCode);
    }

    return ApiException(
      'Erro do servidor (código $statusCode).',
      statusCode: statusCode,
    );
  }
}

/// Decodifica JSON de forma segura, retornando null se falhar.
dynamic _safeJsonDecode(String source) {
  try {
    return jsonDecode(source);
  } catch (_) {
    return null;
  }
}

class ApiService {
  static const String _baseUrl = 'https://api.papacapim.just.pro.br';

  static String get baseUrl => _baseUrl;

  /// Headers de autenticação — lê o token diretamente do AuthManager global.
  static Map<String, String> _authHeaders() => {
    'Content-Type': 'application/json',
    'x-session-token': AuthManager.instance.currentSession?.token ?? '',
  };

  // --- SESSÃO ---

  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/sessions');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': login, 'password': password}),
      );

      final body = _safeJsonDecode(response.body);

      if (response.statusCode == 200 && body is Map<String, dynamic>) {
        return body;
      } else {
        throw ApiException.fromResponse(
          response.statusCode,
          body,
          isLoginAttempt: true,
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<void> deleteSession() async {
    final url = Uri.parse('$_baseUrl/sessions/1');
    await http.delete(url, headers: _authHeaders());
  }

  // --- USUÁRIOS ---

  static Future<Map<String, dynamic>> createUser({
    required String login,
    required String name,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/users');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user': {
            'login': login,
            'name': name,
            'password': password,
            'password_confirmation': passwordConfirmation,
          },
        }),
      );

      final body = _safeJsonDecode(response.body);

      if (response.statusCode == 201 && body is Map<String, dynamic>) {
        return body;
      } else {
        throw ApiException.fromResponse(response.statusCode, body);
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<Map<String, dynamic>> getUser(String login) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$login');
      final response = await http.get(url, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is Map<String, dynamic>) return body;
        throw ApiException('Resposta inesperada do servidor.');
      } else {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<Map<String, dynamic>> updateUser({
    String? login,
    String? name,
    String? password,
    String? passwordConfirmation,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/users/1');

      final userData = <String, dynamic>{};
      if (login != null && login.isNotEmpty) userData['login'] = login;
      if (name != null && name.isNotEmpty) userData['name'] = name;
      if (password != null && password.isNotEmpty) {
        userData['password'] = password;
        userData['password_confirmation'] = passwordConfirmation ?? password;
      }

      final response = await http.patch(
        url,
        headers: _authHeaders(),
        body: jsonEncode({'user': userData}),
      );

      final body = _safeJsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map<String, dynamic>) {
        return body;
      } else {
        throw ApiException.fromResponse(response.statusCode, body);
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<void> deleteUser() async {
    try {
      final url = Uri.parse('$_baseUrl/users/1');
      final response = await http.delete(url, headers: _authHeaders());

      if (response.statusCode != 204) {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  // --- POSTAGENS ---

  static Future<List<dynamic>> getPosts({
    bool feedOnly = false,
    int? page,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (feedOnly) queryParams['feed'] = '1';
      if (page != null) queryParams['page'] = page.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse(
        '$_baseUrl/posts',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is List) return body;
        throw ApiException('Resposta inesperada do servidor.');
      } else {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<List<dynamic>> getUserPosts(String login, {int? page}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();

      final uri = Uri.parse(
        '$_baseUrl/users/$login/posts',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is List) return body;
        throw ApiException('Resposta inesperada do servidor.');
      } else {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<void> createPost(String message) async {
    try {
      final url = Uri.parse('$_baseUrl/posts');

      final response = await http.post(
        url,
        headers: _authHeaders(),
        body: jsonEncode({
          'post': {'message': message},
        }),
      );

      if (response.statusCode != 201) {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<void> deletePost(int postId) async {
    try {
      final url = Uri.parse('$_baseUrl/posts/$postId');
      final response = await http.delete(url, headers: _authHeaders());

      if (response.statusCode != 204) {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  // --- RESPOSTAS (REPLIES) ---

  static Future<List<dynamic>> getReplies(int postId, {int? page}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();

      final uri = Uri.parse(
        '$_baseUrl/posts/$postId/replies',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is List) return body;
        throw ApiException('Resposta inesperada do servidor.');
      } else {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<Map<String, dynamic>> createReply(
    int postId,
    String message,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/posts/$postId/replies');
      final response = await http.post(
        url,
        headers: _authHeaders(),
        body: jsonEncode({
          "reply": {"message": message},
        }),
      );

      final body = _safeJsonDecode(response.body);

      if (response.statusCode == 201 && body is Map<String, dynamic>) {
        return body;
      } else {
        throw ApiException.fromResponse(response.statusCode, body);
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  // --- CURTIDAS (LIKES) ---

  static Future<List<dynamic>> getPostLikes(int postId) async {
    try {
      final url = Uri.parse('$_baseUrl/posts/$postId/likes');
      final response = await http.get(url, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is List) return body;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> likePost(int postId) async {
    try {
      final url = Uri.parse('$_baseUrl/posts/$postId/likes');
      final response = await http.post(
        url,
        headers: _authHeaders(),
        body: jsonEncode({}),
      );

      if (response.statusCode != 201 && response.statusCode != 422) {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<void> unlikePost(int postId) async {
    try {
      final url = Uri.parse('$_baseUrl/posts/$postId/likes/1');
      final response = await http.delete(url, headers: _authHeaders());

      if (response.statusCode != 204 &&
          response.statusCode != 200 &&
          response.statusCode != 422) {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  // --- SEGUIDORES ---

  static Future<List<dynamic>> getFollowers(String login) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$login/followers');
      final response = await http.get(url, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is List) return body;
        throw ApiException('Resposta inesperada do servidor.');
      } else {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<void> followUser(String login) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$login/followers');
      final response = await http.post(
        url,
        headers: _authHeaders(),
        body: jsonEncode({}),
      );

      if (response.statusCode != 201 && response.statusCode != 422) {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<void> unfollowUser(String login) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$login/followers/1');
      final response = await http.delete(url, headers: _authHeaders());

      if (response.statusCode != 204 &&
          response.statusCode != 200 &&
          response.statusCode != 422) {
        throw ApiException.fromResponse(
          response.statusCode,
          _safeJsonDecode(response.body),
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  // --- BUSCA (Corrigido conforme Documentação) ---

  static Future<List<dynamic>> searchUsers(String query, {int? page}) async {
    try {
      final queryParams = <String, String>{'search': query};
      if (page != null) queryParams['page'] = page.toString();

      final uri = Uri.parse(
        '$_baseUrl/users',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is List) return body;
        throw ApiException('Resposta inesperada do servidor.');
      }
      throw ApiException.fromResponse(
        response.statusCode,
        _safeJsonDecode(response.body),
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }

  static Future<List<dynamic>> searchPosts(String query, {int? page}) async {
    try {
      final queryParams = <String, String>{'search': query};
      if (page != null) queryParams['page'] = page.toString();

      final uri = Uri.parse(
        '$_baseUrl/posts',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _authHeaders());

      if (response.statusCode == 200) {
        final body = _safeJsonDecode(response.body);
        if (body is List) return body;
        throw ApiException('Resposta inesperada do servidor.');
      }
      throw ApiException.fromResponse(
        response.statusCode,
        _safeJsonDecode(response.body),
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com a internet. Verifique sua rede.');
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } catch (e) {
      throw ApiException('Erro inesperado: ${e.runtimeType}');
    }
  }
}
