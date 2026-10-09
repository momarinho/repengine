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

  /// Finaliza uma sessão de treino ativa no Go Core.
  Future<SyncPushItemStatus> completeSession(
    int sessionId,
    String authHeader, {
    String? clientId,
    String notes = '',
  }) async {
    final effectiveClientId = clientId ?? 'session-$sessionId';
    final url = Uri.parse('$baseUrl/workout-sessions/$sessionId/complete');

    try {
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({'notes': notes}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return SyncPushItemStatus(
          clientId: effectiveClientId,
          status: SyncItemStatus.accepted,
          serverId: sessionId,
        );
      } else {
        return SyncPushItemStatus(
          clientId: effectiveClientId,
          status: SyncItemStatus.conflictFlagged,
          message: 'Server error completing session: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      return SyncPushItemStatus(
        clientId: effectiveClientId,
        status: SyncItemStatus.conflictFlagged,
        message: 'Network failure completing session: $e',
      );
    }
  }

  /// Abandona uma sessão de treino no Go Core.
  Future<SyncPushItemStatus> abandonSession(
    int sessionId,
    String authHeader, {
    String? clientId,
    String notes = '',
  }) async {
    final effectiveClientId = clientId ?? 'session-$sessionId';
    final url = Uri.parse('$baseUrl/workout-sessions/$sessionId/abandon');

    try {
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({'notes': notes}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return SyncPushItemStatus(
          clientId: effectiveClientId,
          status: SyncItemStatus.accepted,
          serverId: sessionId,
        );
      } else {
        return SyncPushItemStatus(
          clientId: effectiveClientId,
          status: SyncItemStatus.conflictFlagged,
          message: 'Server error abandoning session: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      return SyncPushItemStatus(
        clientId: effectiveClientId,
        status: SyncItemStatus.conflictFlagged,
        message: 'Network failure abandoning session: $e',
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

  /// Busca a lista de workflows do usuário no Go Core para sync delta (Pull),
  /// hidratando os blocos de cada rotina (exercícios, seções, progressões).
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

    final basicWorkflows = list
        .map((w) => Workflow.fromJson(w as Map<String, dynamic>))
        .toList();

    // Hidrata os blocos detalhados para cada workflow ativo
    final hydratedWorkflows = await Future.wait(
      basicWorkflows.map((w) async {
        if (w.isDeleted) return w;
        try {
          final detailUrl = Uri.parse('$baseUrl/workflows/${w.id}');
          final detailRes = await _httpClient.get(
            detailUrl,
            headers: {
              'Accept': 'application/json',
              'Authorization': authHeader,
            },
          );
          if (detailRes.statusCode == 200) {
            final detailData =
                jsonDecode(detailRes.body) as Map<String, dynamic>;
            return Workflow.fromJson(detailData);
          }
        } catch (_) {
          // Mantém o workflow básico caso a chamada individual falhe
        }
        return w;
      }),
    );

    return hydratedWorkflows;
  }

  /// Autentica o atleta ou treinador no Go Core via e-mail e senha.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await _httpClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      final msg = data['error'] ?? data['message'] ?? 'Falha na autenticação';
      throw GoCoreAuthException(response.statusCode, msg.toString());
    } on FormatException {
      throw GoCoreAuthException(
        response.statusCode,
        'Resposta inválida do servidor (${response.statusCode})',
      );
    }
  }
}

/// Exceção para erros de autenticação originados no Go Core.
class GoCoreAuthException implements Exception {
  final int statusCode;
  final String message;

  GoCoreAuthException(this.statusCode, this.message);

  @override
  String toString() => 'GoCoreAuthException($statusCode): $message';
}
