import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_configuration.dart';

class EmailAuthService {
  EmailAuthService._();

  static final EmailAuthService instance = EmailAuthService._();

  final http.Client _client = http.Client();
  String? _accessToken;
  String? _signedInEmail;

  bool get isConfigured => AuthConfiguration.isConfigured;
  String? get signedInEmail => _signedInEmail;

  Future<void> sendCode(String email) async {
    _ensureConfigured();
    final response = await _client.post(
      _endpoint('/auth/v1/otp'),
      headers: _headers,
      body: jsonEncode({'email': email.trim(), 'create_user': true}),
    );
    _checkResponse(response, 'Could not send a sign-in code.');
  }

  Future<String> verifyCode({
    required String email,
    required String code,
  }) async {
    _ensureConfigured();
    final response = await _client.post(
      _endpoint('/auth/v1/verify'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim(),
        'token': code.trim(),
        'type': 'email',
      }),
    );
    final data = _decodeResponse(response, 'That code could not be verified.');
    final token = data['access_token'];
    final user = data['user'];
    final verifiedEmail = user is Map<String, dynamic> ? user['email'] : null;
    if (token is! String || verifiedEmail is! String) {
      throw const EmailAuthException(
        'The account service returned an incomplete sign-in response.',
      );
    }
    _accessToken = token;
    _signedInEmail = verifiedEmail;
    return verifiedEmail;
  }

  Future<void> signOut() async {
    final token = _accessToken;
    _accessToken = null;
    _signedInEmail = null;
    if (token == null || !isConfigured) return;
    await _client.post(
      _endpoint('/auth/v1/logout'),
      headers: {..._headers, 'Authorization': 'Bearer $token'},
    );
  }

  Uri _endpoint(String path) => Uri.parse(
    '${AuthConfiguration.supabaseUrl.replaceFirst(RegExp(r'/+$'), '')}$path',
  );

  Map<String, String> get _headers => {
    'apikey': AuthConfiguration.supabaseAnonKey,
    'Content-Type': 'application/json',
  };

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const EmailAuthException('Email sign-in is not connected yet.');
    }
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    String fallback,
  ) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['msg'] ?? decoded['message'] ?? decoded['error_description']
          : null;
      throw EmailAuthException(
        message is String && message.isNotEmpty ? message : fallback,
      );
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  void _checkResponse(http.Response response, String fallback) {
    _decodeResponse(response, fallback);
  }
}

class EmailAuthException implements Exception {
  const EmailAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
