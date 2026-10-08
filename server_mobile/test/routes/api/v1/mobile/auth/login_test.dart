import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_mobile/src/services/go_core_client.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/mobile/auth/login.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _MockGoCoreClient extends Mock implements GoCoreClient {}

void main() {
  group('POST /api/v1/mobile/auth/login', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late _MockGoCoreClient client;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      client = _MockGoCoreClient();

      when(() => context.request).thenReturn(request);
      when(() => context.read<GoCoreClient>()).thenReturn(client);
    });

    test('returns 405 Method Not Allowed when method is GET', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('returns 400 Bad Request when JSON is invalid', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer((_) async => 'not-a-json');

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 Bad Request when email or password is empty', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({'email': '', 'password': ''}),
      );

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('authenticates successfully and returns token payload', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'email': 'atleta@repengine.com',
          'password': 'password123',
        }),
      );

      when(() => client.login('atleta@repengine.com', 'password123'))
          .thenAnswer((_) async => {
                'message': 'logged in',
                'user_id': 15,
                'token': 'signed-jwt-token-15',
              });

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json() as Map<String, dynamic>;
      expect(body['user_id'], equals(15));
      expect(body['token'], equals('signed-jwt-token-15'));
    });

    test('returns 401 when Go Core rejects credentials', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'email': 'atleta@repengine.com',
          'password': 'wrongpassword',
        }),
      );

      when(() => client.login('atleta@repengine.com', 'wrongpassword'))
          .thenThrow(GoCoreAuthException(401, 'Credenciais inválidas'));

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
      final body = await response.json() as Map<String, dynamic>;
      expect(body['error'], equals('Credenciais inválidas'));
    });
  });
}
