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
  final sessionClientToServerId = <String, int>{};

  // 4. Processar cada sessão do lote
  for (final session in payload.sessions) {
    final status = await client.forwardSession(session, authHeader);
    itemsResult.add(status);
    if (status.serverId != null && session.clientId != null) {
      sessionClientToServerId[session.clientId!] = status.serverId!;
    }
  }

  // 5. Processar cada série individual do lote (resolvendo session_id offline)
  for (final log in payload.setLogs) {
    var logToForward = log;
    if ((log.sessionId == null || log.sessionId! <= 0) &&
        log.sessionClientId != null &&
        sessionClientToServerId.containsKey(log.sessionClientId)) {
      final serverSessionId = sessionClientToServerId[log.sessionClientId]!;
      logToForward = WorkoutSetLog(
        id: log.id,
        sessionId: serverSessionId,
        sessionClientId: log.sessionClientId,
        workflowBlockId: log.workflowBlockId,
        blockClientId: log.blockClientId,
        nodeTypeSlug: log.nodeTypeSlug,
        setIndex: log.setIndex,
        prescribedReps: log.prescribedReps,
        prescribedLoad: log.prescribedLoad,
        prescribedIntensity: log.prescribedIntensity,
        prescribedRpe: log.prescribedRpe,
        actualReps: log.actualReps,
        actualLoad: log.actualLoad,
        actualRpe: log.actualRpe,
        actualRir: log.actualRir,
        completed: log.completed,
        notes: log.notes,
        clientId: log.clientId,
        createdAt: log.createdAt,
      );
    }
    final status = await client.forwardSetLog(logToForward, authHeader);
    itemsResult.add(status);
  }

  // 6. Montar o recibo final de sincronização
  final result = SyncPushResult(
    items: itemsResult,
    processedAt: DateTime.now().toUtc(),
  );

  return Response.json(body: result.toJson());
}
