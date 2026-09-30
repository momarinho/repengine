import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:server_mobile/src/services/go_core_client.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Garantir que apenas requisições POST são aceitas nessa rota
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // 2. Recuperar dependências injetadas pelos Middlewares
  final client = context.read<GoCoreClient>();
  final authHeader = context.request.headers['authorization']!;

  // 3. Ler o corpo da requisição e converter para o DTO do nosso pacote
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Invalid JSON body'},
    );
  }

  final payload = SyncPushPayload.fromJson(body);
  final itemsResult = <SyncPushItemStatus>[];

  // 4. Processar cada sessão do lote
  for (final session in payload.sessions) {
    final status = await client.forwardSession(session, authHeader);
    itemsResult.add(status);
  }

  // 5. Processar cada série individual do lote
  for (final log in payload.setLogs) {
    final status = await client.forwardSetLog(log, authHeader);
    itemsResult.add(status);
  }

  // 6. Montar o recibo final de sincronização
  final result = SyncPushResult(
    items: itemsResult,
    processedAt: DateTime.now().toUtc(),
  );

  return Response.json(body: result.toJson());
}
