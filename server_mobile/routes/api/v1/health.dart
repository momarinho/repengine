import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  return Response.json(
    body: {
      'status': 'ok',
      'service': 'repengine_mobile_bff',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    },
  );
}
