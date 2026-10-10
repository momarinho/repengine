import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_mobile/src/services/gemini_client.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/mobile/ai/generate_routine.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _MockGeminiClient extends Mock implements GeminiClient {}

void main() {
  group('POST /api/v1/mobile/ai/generate-routine', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late _MockGeminiClient geminiClient;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      geminiClient = _MockGeminiClient();

      when(() => context.request).thenReturn(request);
      when(() => request.headers).thenReturn({});
      when(() => context.read<GeminiClient>()).thenReturn(geminiClient);
    });

    test('returns 405 Method Not Allowed when method is GET', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('returns 400 Bad Request when request body is not valid JSON', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenThrow(const FormatException('Bad JSON'));

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 Bad Request when prompt is empty or missing', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {'prompt': '   '});

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 503 Service Unavailable when GEMINI_API_KEY is not configured', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {'prompt': 'Heavy leg day'});
      when(
        () => geminiClient.generateRoutine(
          'Heavy leg day',
          goal: any(named: 'goal'),
          split: any(named: 'split'),
          experienceLevel: any(named: 'experienceLevel'),
          equipment: any(named: 'equipment'),
          constraints: any(named: 'constraints'),
          apiKey: any(named: 'apiKey'),
        ),
      ).thenThrow(const GeminiMissingKeyException());

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.serviceUnavailable));
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['error'], contains('GEMINI_API_KEY is not configured'));
    });

    test('returns 502 Bad Gateway when Gemini API throws GeminiApiException', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {'prompt': 'Heavy leg day'});
      when(
        () => geminiClient.generateRoutine(
          'Heavy leg day',
          goal: any(named: 'goal'),
          split: any(named: 'split'),
          experienceLevel: any(named: 'experienceLevel'),
          equipment: any(named: 'equipment'),
          constraints: any(named: 'constraints'),
          apiKey: any(named: 'apiKey'),
        ),
      ).thenThrow(const GeminiApiException(429, 'Rate limit exceeded'));

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badGateway));
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['error'], contains('429'));
    });

    test('returns 200 OK with generated routine when successful', () async {
      final mockRoutine = {
        'routine_name': 'Push Pull Legs',
        'description': 'AI Generated routine',
        'days': [],
        'blocks': [
          {
            'id': 'sec_1',
            'node_type_slug': 'section',
            'data': {'title': 'Day 1 - Push'},
          },
        ],
      };

      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer(
        (_) async => {'prompt': '3-day PPL strength routine'},
      );
      when(
        () => geminiClient.generateRoutine(
          '3-day PPL strength routine',
          goal: any(named: 'goal'),
          split: any(named: 'split'),
          experienceLevel: any(named: 'experienceLevel'),
          equipment: any(named: 'equipment'),
          constraints: any(named: 'constraints'),
          apiKey: any(named: 'apiKey'),
        ),
      ).thenAnswer((_) async => mockRoutine);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['routine_name'], equals('Push Pull Legs'));
      expect(body['blocks'], isNotEmpty);
    });

    test('forwards client-provided x-gemini-api-key to geminiClient', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.headers).thenReturn({'x-gemini-api-key': 'user-custom-key'});
      when(() => request.json()).thenAnswer(
        (_) async => {'prompt': 'Upper Body Routine'},
      );
      when(
        () => geminiClient.generateRoutine(
          'Upper Body Routine',
          goal: any(named: 'goal'),
          split: any(named: 'split'),
          experienceLevel: any(named: 'experienceLevel'),
          equipment: any(named: 'equipment'),
          constraints: any(named: 'constraints'),
          apiKey: 'user-custom-key',
        ),
      ).thenAnswer((_) async => {'routine_name': 'Upper Body', 'blocks': []});

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      verify(
        () => geminiClient.generateRoutine(
          'Upper Body Routine',
          goal: any(named: 'goal'),
          split: any(named: 'split'),
          experienceLevel: any(named: 'experienceLevel'),
          equipment: any(named: 'equipment'),
          constraints: any(named: 'constraints'),
          apiKey: 'user-custom-key',
        ),
      ).called(1);
    });
  });
}
