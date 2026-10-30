import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_mobile/src/services/go_core_client.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/mobile/auth/register.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _MockGoCoreClient extends Mock implements GoCoreClient {}

void main() {
  group('POST /api/v1/mobile/auth/register', () {
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

    test('registers user successfully and returns 201 Created payload', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'email': 'novoatleta@repengine.com',
          'password': 'password123',
        }),
      );

      when(() => client.register('novoatleta@repengine.com', 'password123'))
          .thenAnswer((_) async => {
                'message': 'user created',
                'user_id': 42,
              });

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.created));
      final body = await response.json() as Map<String, dynamic>;
      expect(body['user_id'], equals(42));
      expect(body['message'], equals('user created'));
    });

    test('returns 409 Conflict when user already exists in Go Core', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'email': 'atleta@repengine.com',
          'password': 'password123',
        }),
      );

      when(() => client.register('atleta@repengine.com', 'password123'))
          .thenThrow(GoCoreAuthException(409, 'Email já cadastrado'));

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.conflict));
      final body = await response.json() as Map<String, dynamic>;
      expect(body['error'], equals('Email já cadastrado'));
    });
  });
}
