import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../routes/api/v1/mobile/_middleware.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

void main() {
  group('Mobile Auth Middleware', () {
    late _MockRequestContext context;
    late _MockRequest request;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      when(() => context.request).thenReturn(request);
      when(() => request.uri).thenReturn(Uri.parse('http://localhost/api/v1/mobile/sync/pull'));
    });

    test('bypasses authentication for /auth/login endpoint', () async {
      when(() => request.uri).thenReturn(Uri.parse('http://localhost/api/v1/mobile/auth/login'));
      when(() => request.headers).thenReturn({});

      var handlerInvoked = false;
      final handler = middleware((ctx) async {
        handlerInvoked = true;
        return Response();
      });

      final response = await handler(context);
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(handlerInvoked, isTrue);
    });

    test('returns 401 when Authorization header is missing', () async {
      when(() => request.headers).thenReturn({});

      final handler = middleware((_) async => Response());
      final response = await handler(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('returns 401 when token is invalid', () async {
      when(() => request.headers).thenReturn({
        'authorization': 'Bearer token-invalido-xyz',
      });

      final handler = middleware((_) async => Response());
      final response = await handler(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('injects userId and forwards when token is valid', () async {
      final jwt = JWT({'user_id': 42});
      final validToken = jwt.sign(SecretKey('dev-secret-key'));

      when(() => request.headers).thenReturn({
        'authorization': 'Bearer $validToken',
      });
      when(() => context.provide<int>(any())).thenReturn(context);

      var handlerInvoked = false;
      final handler = middleware((ctx) async {
        handlerInvoked = true;
        return Response();
      });

      final response = await handler(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(handlerInvoked, isTrue);
    });
  });
}
