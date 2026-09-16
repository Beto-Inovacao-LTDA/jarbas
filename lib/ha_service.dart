import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class HaServiceException implements Exception {
  const HaServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HaUnauthorizedException extends HaServiceException {
  const HaUnauthorizedException() : super('Token inválido ou não autorizado.');
}

class HaTimeoutException extends HaServiceException {
  const HaTimeoutException() : super('Tempo de resposta esgotado.');
}

class HaConnectionException extends HaServiceException {
  const HaConnectionException()
    : super('Falha ao conectar ao Home Assistant.');
}

class HaUnexpectedResponseException extends HaServiceException {
  const HaUnexpectedResponseException()
    : super('Resposta inesperada do Home Assistant.');
}

/// Único ponto de contato HTTP com o Home Assistant. Não interpreta
/// comandos: delega 100% ao Assist do HA (RF-13).
class HaService {
  HaService({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 10);

  final http.Client _client;
  final Duration _timeout;

  Future<String> sendCommand(String baseUrl, String token, String text) async {
    final response = await _postConversation(baseUrl, token, text);
    _checkStatus(response);

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final speech =
          body['response']['speech']['plain']['speech'] as String;
      return speech;
    } catch (_) {
      throw const HaUnexpectedResponseException();
    }
  }

  Future<bool> testConnection(String baseUrl, String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    }
  }

  Future<http.Response> _postConversation(
    String baseUrl,
    String token,
    String text,
  ) async {
    try {
      return await _client
          .post(
            Uri.parse('$baseUrl/api/conversation/process'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'text': text, 'language': 'pt-BR'}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const HaTimeoutException();
    } on SocketException {
      throw const HaConnectionException();
    } on http.ClientException {
      throw const HaConnectionException();
    }
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) {
      throw const HaUnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const HaUnexpectedResponseException();
    }
  }
}
