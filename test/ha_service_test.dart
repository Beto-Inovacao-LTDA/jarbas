import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ha_voice_app/ha_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://ha.local:8123';
  const token = 'test-token';

  group('HaService.sendCommand', () {
    test('monta URL, headers e corpo corretos', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late String capturedBody;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'response': {
              'speech': {
                'plain': {'speech': 'ok'},
              },
            },
          }),
          200,
        );
      });

      final service = HaService(client: client);
      await service.sendCommand(baseUrl, token, 'acender as luzes');

      expect(capturedUri, Uri.parse('$baseUrl/api/conversation/process'));
      expect(capturedHeaders['Authorization'], 'Bearer $token');
      expect(capturedHeaders['Content-Type'], contains('application/json'));
      expect(jsonDecode(capturedBody), {
        'text': 'acender as luzes',
        'language': 'pt-BR',
      });
    });

    test('extrai response.speech.plain.speech de uma resposta 200', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'response': {
              'speech': {
                'plain': {'speech': 'Luzes acesas'},
              },
            },
          }),
          200,
        );
      });

      final service = HaService(client: client);
      final speech = await service.sendCommand(baseUrl, token, 'acender');

      expect(speech, 'Luzes acesas');
    });

    test('401 lança HaUnauthorizedException', () async {
      final client = MockClient((request) async => http.Response('', 401));
      final service = HaService(client: client);

      expect(
        () => service.sendCommand(baseUrl, token, 'acender'),
        throwsA(isA<HaUnauthorizedException>()),
      );
    });

    test('timeout lança HaTimeoutException', () async {
      final client = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response('', 200);
      });
      final service = HaService(
        client: client,
        timeout: const Duration(milliseconds: 5),
      );

      expect(
        () => service.sendCommand(baseUrl, token, 'acender'),
        throwsA(isA<HaTimeoutException>()),
      );
    });

    test('falha de conexão lança HaConnectionException', () async {
      final client = MockClient((request) async {
        throw const SocketException('unreachable');
      });
      final service = HaService(client: client);

      expect(
        () => service.sendCommand(baseUrl, token, 'acender'),
        throwsA(isA<HaConnectionException>()),
      );
    });

    test(
      'erro inesperado (ex.: URL inválida/sem host) lança HaConnectionException, sem travar o chamador',
      () async {
        final client = MockClient((request) async {
          throw ArgumentError('No host specified in URI /api/conversation/process');
        });
        final service = HaService(client: client);

        expect(
          () => service.sendCommand('', token, 'acender'),
          throwsA(isA<HaConnectionException>()),
        );
      },
    );

    test(
      'corpo sem o campo esperado lança HaUnexpectedResponseException',
      () async {
        final client = MockClient((request) async {
          return http.Response(jsonEncode({'foo': 'bar'}), 200);
        });
        final service = HaService(client: client);

        expect(
          () => service.sendCommand(baseUrl, token, 'acender'),
          throwsA(isA<HaUnexpectedResponseException>()),
        );
      },
    );
  });

  group('HaService.testConnection', () {
    test('retorna true para status 2xx', () async {
      final client = MockClient((request) async => http.Response('', 200));
      final service = HaService(client: client);

      expect(await service.testConnection(baseUrl, token), isTrue);
    });

    test('retorna false para 401', () async {
      final client = MockClient((request) async => http.Response('', 401));
      final service = HaService(client: client);

      expect(await service.testConnection(baseUrl, token), isFalse);
    });

    test('retorna false em falha de conexão', () async {
      final client = MockClient((request) async {
        throw const SocketException('unreachable');
      });
      final service = HaService(client: client);

      expect(await service.testConnection(baseUrl, token), isFalse);
    });

    test(
      'retorna false para URL vazia/inválida, sem travar o chamador',
      () async {
        final client = MockClient((request) async {
          throw ArgumentError('No host specified in URI /api/');
        });
        final service = HaService(client: client);

        expect(await service.testConnection('', token), isFalse);
      },
    );
  });
}
