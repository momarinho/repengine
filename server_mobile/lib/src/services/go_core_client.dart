import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:repengine_core/repengine_core.dart';

/// Cliente HTTP responsável por encaminhar operações de sincronização
/// do Dart Frog BFF para o Go Core API.
class GoCoreClient {
  /// Cria uma instância do [GoCoreClient].
  GoCoreClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// URL base do serviço Go Core (ex: http://api:8080).
  final String baseUrl;

  final http.Client _httpClient;

  /// Encaminha uma sessão criada offline para o Go Core.
  Future<SyncPushItemStatus> forwardSession(
    WorkoutSession session,
    String authHeader,
  ) async {
    final clientId = session.clientId ?? 'session-${session.id}';
    final workflowId = session.workflowId;
    final url = Uri.parse('$baseUrl/workflows/$workflowId/sessions');

    try {
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({
          'workflow_id': session.workflowId,
          'section_id': session.sectionId,
          'section_title': session.sectionTitle,
          'client_id': clientId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverId = data['id'] as int?;

        return SyncPushItemStatus(
          clientId: clientId,
          status: SyncItemStatus.accepted,
          serverId: serverId,
        );
      } else if (response.statusCode == 409) {
        return SyncPushItemStatus(
          clientId: clientId,
          status: SyncItemStatus.ignoredDuplicate,
          message: 'Session already exists on server',
        );
      } else {
        return SyncPushItemStatus(
          clientId: clientId,
          status: SyncItemStatus.conflictFlagged,
          message: 'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      return SyncPushItemStatus(
        clientId: clientId,
        status: SyncItemStatus.conflictFlagged,
        message: 'Network failure forwarding session: $e',
      );
    }
  }

  /// Encaminha um log de série individual para o Go Core.
  Future<SyncPushItemStatus> forwardSetLog(
    WorkoutSetLog log,
    String authHeader,
  ) async {
    final clientId = log.clientId ?? 'log-${log.id}';
    final sessionId = log.sessionId;

    if (sessionId == null || sessionId <= 0) {
      return SyncPushItemStatus(
        clientId: clientId,
        status: SyncItemStatus.conflictFlagged,
        message: 'Missing or invalid session_id for set log',
      );
    }

    final url = Uri.parse('$baseUrl/workout-sessions/$sessionId/logs');

    try {
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({
          'workflow_block_id': log.workflowBlockId,
          'block_client_id': log.blockClientId,
          'node_type_slug': log.nodeTypeSlug,
          'set_index': log.setIndex,
          'prescribed_reps': log.prescribedReps,
          'prescribed_load': log.prescribedLoad,
          'prescribed_intensity': log.prescribedIntensity,
          'prescribed_rpe': log.prescribedRpe,
          'actual_reps': log.actualReps,
          'actual_load': log.actualLoad,
          'actual_rpe': log.actualRpe,
          'actual_rir': log.actualRir,
          'completed': log.completed,
          'notes': log.notes,
          'client_id': clientId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverId = data['id'] as int?;

        return SyncPushItemStatus(
          clientId: clientId,
          status: SyncItemStatus.accepted,
          serverId: serverId,
        );
      } else if (response.statusCode == 409) {
        return SyncPushItemStatus(
          clientId: clientId,
          status: SyncItemStatus.ignoredDuplicate,
          message: 'Set log already synced',
        );
      } else {
        return SyncPushItemStatus(
          clientId: clientId,
          status: SyncItemStatus.conflictFlagged,
          message: 'Server rejected log: ${response.statusCode} - '
              '${response.body}',
        );
      }
    } catch (e) {
      return SyncPushItemStatus(
        clientId: clientId,
        status: SyncItemStatus.conflictFlagged,
        message: 'Network failure forwarding set log: $e',
      );
    }
  }

  /// Busca a lista de workflows do usuário no Go Core para sync delta (Pull).
  Future<List<Workflow>> fetchWorkflows(String authHeader) async {
    final url = Uri.parse('$baseUrl/workflows?limit=100');

    final response = await _httpClient.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': authHeader,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch workflows from Go Core: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>? ?? const [];

    return list
        .map((w) => Workflow.fromJson(w as Map<String, dynamic>))
        .toList();
  }
}
