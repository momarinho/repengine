import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:server_mobile/src/services/go_core_client.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Apenas requisições GET são aceitas nesta rota
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final client = context.read<GoCoreClient>();
  final authHeader = context.request.headers['authorization']!;

  // 2. Extrai o parâmetro opcional 'last_synced_at' da query string
  final lastSyncedAtRaw =
      context.request.uri.queryParameters['last_synced_at'];
  DateTime? lastSyncedAt;
  if (lastSyncedAtRaw != null && lastSyncedAtRaw.isNotEmpty) {
    try {
      lastSyncedAt = DateTime.parse(lastSyncedAtRaw);
    } catch (_) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'error': 'Invalid ISO-8601 date in last_synced_at'},
      );
    }
  }

  // 3. Busca a lista de workflows do atleta no Go Core
  final List<Workflow> allWorkflows;
  try {
    allWorkflows = await client.fetchWorkflows(authHeader);
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.badGateway,
      body: {'error': 'Failed to reach Go Core API: $e'},
    );
  }

  final List<Workflow> updatedWorkflows;
  final List<int> deletedIds;

  // 4. Aplica o filtro de delta sincronização
  if (lastSyncedAt == null) {
    // Primeiro sync: envia tudo o que não foi deletado
    updatedWorkflows = allWorkflows.where((w) => !w.isDeleted).toList();
    deletedIds = const [];
  } else {
    // Sync incremental: filtra apenas novidades e deleções pós-timestamp
    final since = lastSyncedAt;
    updatedWorkflows = allWorkflows
        .where((w) =>
            !w.isDeleted &&
            (w.updatedAt.isAfter(since) || w.updatedAt.isAtSameMomentAs(since)))
        .toList();

    deletedIds = allWorkflows
        .where((w) =>
            w.deletedAt != null &&
            (w.deletedAt!.isAfter(since) ||
                w.deletedAt!.isAtSameMomentAs(since)))
        .map((w) => w.id)
        .toList();
  }

  // 5. Monta o DTO de resposta do nosso repengine_core
  final responsePayload = SyncPullResponse(
    updatedWorkflows: updatedWorkflows,
    deletedWorkflowIds: deletedIds,
    serverTimestamp: DateTime.now().toUtc(),
  );

  return Response.json(body: responsePayload.toJson());
}
