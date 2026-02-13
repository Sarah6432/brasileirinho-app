import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://api.papacapim.just.pro.br';

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

  static Future<List<dynamic>> getPosts(String token) async {
    final url = Uri.parse('$_baseUrl/posts');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao buscar posts: ${response.statusCode}');
    }
  }

  static Future<void> createPost(String token, String message) async {
    final url = Uri.parse('$_baseUrl/posts');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'post': {
          'message': message,
        }
      }),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['errors'] ?? 'Erro ao criar post');
    }
  }
}