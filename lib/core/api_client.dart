import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8000/api/v1',
          ),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? accessToken;

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ' + accessToken!;
    }
    return headers;
  }

  Future<AuthSession> login(String identifier, String password) async {
    final response = await _client.post(
      Uri.parse(baseUrl + '/auth/login'),
      headers: _headers,
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw ApiException(_errorText(response));
    }
    return AuthSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<SyncResponse> synchronize({
    required int cursor,
    required List<SyncChange> changes,
  }) async {
    final response = await _client.post(
      Uri.parse(baseUrl + '/sync'),
      headers: _headers,
      body: jsonEncode({
        'cursor': cursor,
        'changes': changes.map((change) => change.toJson()).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(_errorText(response));
    }
    return SyncResponse.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<bool> health() async {
    try {
      final response = await _client.get(
        Uri.parse(baseUrl.replaceFirst('/api/v1', '') + '/health'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _errorText(http.Response response) {
    try {
      final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      return body['detail']?.toString() ?? 'خطا در ارتباط با سرور';
    } catch (_) {
      return 'خطا در ارتباط با سرور (' + response.statusCode.toString() + ')';
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
