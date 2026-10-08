import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:server_mobile/src/services/go_core_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final client = context.read<GoCoreClient>();

  final bodyRaw = await context.request.body();
  final Map<String, dynamic> body;
  try {
    body = jsonDecode(bodyRaw) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Corpo da requisição deve ser um JSON válido'},
    );
  }

  final email = body['email']?.toString().trim() ?? '';
  final password = body['password']?.toString() ?? '';

  if (email.isEmpty || password.isEmpty) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'E-mail e senha são obrigatórios'},
    );
  }

  try {
    final result = await client.login(email, password);
    return Response.json(body: result);
  } on GoCoreAuthException catch (e) {
    return Response.json(
      statusCode: e.statusCode,
      body: {'error': e.message},
    );
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.badGateway,
      body: {'error': 'Falha ao conectar com o servidor Go Core: $e'},
    );
  }
}
