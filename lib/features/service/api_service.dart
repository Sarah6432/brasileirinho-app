import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://api.papacapim.just.pro.br';

  static String get baseUrl => _baseUrl;

  static Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'x-session-token': token,
  };

  // --- SESSÃO ---

  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/sessions');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'password': password}),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body;
    } else {
      final errors = body is Map ? (body['errors'] ?? body) : body;
      throw Exception('$errors');
    }
  }

  static Future<void> deleteSession(String token) async {
    final url = Uri.parse('$_baseUrl/sessions/1');
    await http.delete(url, headers: _authHeaders(token));
  }

  // --- USUÁRIOS ---

  static Future<Map<String, dynamic>> createUser({
    required String login,
    required String name,
    required String password,
    required String passwordConfirmation,
  }) async {
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

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return body;
    } else {
      final errors = body is Map ? (body['errors'] ?? body) : body;
      throw Exception('$errors');
    }
  }

  static Future<Map<String, dynamic>> getUser(
    String token,
    String login,
  ) async {
    final url = Uri.parse('$_baseUrl/users/$login');
    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao buscar usuário: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    String token, {
    String? login,
    String? name,
    String? password,
    String? passwordConfirmation,
    String? photo,
  }) async {
    final url = Uri.parse('$_baseUrl/users/1');

    final userData = <String, dynamic>{};
    if (login != null && login.isNotEmpty) userData['login'] = login;
    if (name != null && name.isNotEmpty) userData['name'] = name;
    if (photo != null) userData['photo'] = photo;
    if (password != null && password.isNotEmpty) {
      userData['password'] = password;
      userData['password_confirmation'] = passwordConfirmation ?? password;
    }

    final response = await http.patch(
      url,
      headers: _authHeaders(token),
      body: jsonEncode({'user': userData}),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    } else {
      final errors = body is Map ? (body['errors'] ?? body) : body;
      throw Exception('$errors');
    }
  }

  static Future<void> deleteUser(String token) async {
    final url = Uri.parse('$_baseUrl/users/1');
    final response = await http.delete(url, headers: _authHeaders(token));

    if (response.statusCode != 204) {
      throw Exception('Erro ao excluir conta: ${response.statusCode}');
    }
  }

  // --- POSTAGENS ---

  static Future<List<dynamic>> getPosts(String token, {bool feedOnly = false}) async {
    final String query = feedOnly ? '?feed=1' : '';
    final url = Uri.parse('$_baseUrl/posts$query');
    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao buscar posts: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getUserPosts(String token, String login) async {
    final url = Uri.parse('$_baseUrl/users/$login/posts');
    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao buscar posts do usuário: ${response.statusCode}');
    }
  }

  static Future<void> createPost(String token, String message) async {
    final url = Uri.parse('$_baseUrl/posts');

    final response = await http.post(
      url,
      headers: _authHeaders(token),
      body: jsonEncode({
        'post': {'message': message},
      }),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['errors'] ?? 'Erro ao criar post');
    }
  }

  static Future<void> deletePost(String token, int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId');
    final response = await http.delete(url, headers: _authHeaders(token));

    if (response.statusCode != 204) {
      throw Exception('Erro ao excluir post: ${response.statusCode}');
    }
  }

  // --- RESPOSTAS (REPLIES) ---

  static Future<List<dynamic>> getReplies(String token, int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId/replies');
    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao buscar respostas: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createReply(
    String token,
    int postId,
    String message,
  ) async {
    final url = Uri.parse('$_baseUrl/posts/$postId/replies');
    final response = await http.post(
      url,
      headers: _authHeaders(token),
      body: jsonEncode({
        "reply": {"message": message}
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return body;
    } else {
      throw Exception(body['errors'] ?? 'Erro ao responder postagem');
    }
  }

  // --- CURTIDAS (LIKES) ---

  static Future<void> likePost(String token, int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId/likes');
    final response = await http.post(
      url,
      headers: _authHeaders(token),
      body: jsonEncode({}),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 422) {
      throw Exception('Erro ao curtir post: ${response.statusCode}');
    }
  }

  static Future<void> unlikePost(String token, int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId/likes/1');
    final response = await http.delete(url, headers: _authHeaders(token));

    if (response.statusCode != 204 &&
        response.statusCode != 200 &&
        response.statusCode != 422) {
      throw Exception('Erro ao descurtir post: ${response.statusCode}');
    }
  }

  // --- SEGUIDORES ---

  static Future<List<dynamic>> getFollowers(String token, String login) async {
    final url = Uri.parse('$_baseUrl/users/$login/followers');
    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao buscar seguidores: ${response.statusCode}');
    }
  }

  static Future<void> followUser(String token, String login) async {
    final url = Uri.parse('$_baseUrl/users/$login/followers');
    final response = await http.post(
      url,
      headers: _authHeaders(token),
      body: jsonEncode({}),
    );

    if (response.statusCode != 201 && response.statusCode != 422) {
      throw Exception('Erro ao seguir usuário: ${response.statusCode}');
    }
  }

  static Future<void> unfollowUser(String token, String login) async {
    final url = Uri.parse('$_baseUrl/users/$login/followers/1');
    final response = await http.delete(url, headers: _authHeaders(token));

    if (response.statusCode != 204 &&
        response.statusCode != 200 &&
        response.statusCode != 422) {
      throw Exception('Erro ao deixar de seguir: ${response.statusCode}');
    }
  }

  // --- BUSCA (Corrigido conforme Documentação) ---

  static Future<List<dynamic>> searchUsers(String token, String query) async {
    final url = Uri.parse('$_baseUrl/users?search=$query');
    final response = await http.get(url, headers: _authHeaders(token));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao pesquisar usuários');
  }

  static Future<List<dynamic>> searchPosts(String token, String query) async {
    final url = Uri.parse('$_baseUrl/posts?search=$query');
    final response = await http.get(url, headers: _authHeaders(token));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao pesquisar posts');
  }
}