import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

final _jwtSecret = Platform.environment['JWT_SECRET'] ?? 'dev-secret-key';

Handler middleware(Handler handler) {
  return (context) async {
    final authHeader = context.request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'error': 'Missing or malformed Authorization header'},
      );
    }

    final token = authHeader.substring(7).trim();

    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      final payload = jwt.payload as Map<String, dynamic>;

      final userIdRaw = payload['user_id'] ?? payload['sub'];
      final userId =
          userIdRaw is int ? userIdRaw : int.parse(userIdRaw.toString());

      if (userId <= 0) {
        return Response.json(
          statusCode: HttpStatus.unauthorized,
          body: {'error': 'Invalid user_id in token'},
        );
      }

      final updatedContext = context.provide<int>(() => userId);
      return await handler(updatedContext);
    } on JWTExpiredException {
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'error': 'Token expired'},
      );
    } on JWTException catch (e) {
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'error': 'Invalid token: ${e.message}'},
      );
    } catch (_) {
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'error': 'Authentication failed'},
      );
    }
  };
}
