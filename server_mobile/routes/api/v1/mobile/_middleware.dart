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

    final int userId;

    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      final dynamic rawPayload = jwt.payload;
      final payload =
          rawPayload is Map ? rawPayload : const <dynamic, dynamic>{};

      final userIdRaw = payload['user_id'] ?? payload['sub'];
      final parsedId =
          userIdRaw is int
              ? userIdRaw
              : int.tryParse(userIdRaw?.toString() ?? '');

      if (parsedId == null || parsedId <= 0) {
        return Response.json(
          statusCode: HttpStatus.unauthorized,
          body: {'error': 'Invalid user_id in token'},
        );
      }
      userId = parsedId;
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
    } catch (e) {
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'error': 'Authentication failed: $e'},
      );
    }

    final updatedContext = context.provide<int>(() => userId);
    return handler(updatedContext);
  };
}
