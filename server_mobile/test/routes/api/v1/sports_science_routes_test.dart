import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../routes/api/v1/1rm.dart' as route_1rm;
import '../../../../routes/api/v1/acwr.dart' as route_acwr;
import '../../../../routes/api/v1/autoregulation.dart' as route_autoreg;
import '../../../../routes/api/v1/inol.dart' as route_inol;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}

void main() {
  late _MockRequestContext context;
  late _MockRequest request;

  setUp(() {
    context = _MockRequestContext();
    request = _MockRequest();
    when(() => context.request).thenReturn(request);
  });

  group('POST /api/v1/1rm', () {
    test('calcula 1RM com sucesso para payload válido', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer(
        (_) async => {
          'exercise_name': 'Bench Press',
          'load': 100.0,
          'reps': 5,
        },
      );

      final response = await route_1rm.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));

      final jsonStr = await response.body();
      final body = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(body['exercise_name'], equals('Bench Press'));
      expect(body['epley_1rm'], closeTo(116.67, 0.1));
      expect(body['consensus_1rm'], greaterThan(110.0));
      expect(body['reps_projection'], isNotNull);
    });
  });

  group('POST /api/v1/autoregulation', () {
    test('avalia histórico e retorna ação em snake_case', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer(
        (_) async => {
          'exercise_name': 'Squat',
          'sessions': [
            {
              'date': '2026-10-01',
              'target_reps': 5,
              'completed_reps': 5,
              'load': 100.0,
              'rpe': 8.0,
              'failed': false,
            },
          ],
        },
      );

      final response = await route_autoreg.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));

      final jsonStr = await response.body();
      final body = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(body['exercise_name'], equals('Squat'));
      expect(body['recommended_action'], equals('increase_load'));
      expect(body['recommended_load'], equals(102.5));
    });
  });

  group('POST /api/v1/acwr', () {
    test('calcula razão de carga e retorna zona em snake_case', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      final history = List.generate(
        28,
        (i) => {
          'date': DateTime.utc(2026, 9, 1 + i).toIso8601String(),
          'workload': 1000.0,
        },
      );
      when(() => request.json()).thenAnswer(
        (_) async => {
          'exercise_name': 'Deadlift',
          'history': history,
        },
      );

      final response = await route_acwr.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));

      final jsonStr = await response.body();
      final body = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(body['acwr_ratio'], equals(1.0));
      expect(body['zone'], equals('optimal'));
    });
  });

  group('POST /api/v1/inol', () {
    test('calcula INOL total e classificação', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer(
        (_) async => {
          'exercise_name': 'Overhead Press',
          'sets': [
            {'reps': 5, 'intensity_percentage': 80.0},
            {'reps': 5, 'intensity_percentage': 80.0},
          ],
        },
      );

      final response = await route_inol.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));

      final jsonStr = await response.body();
      final body = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(body['total_inol'], equals(0.5));
      expect(body['classification'], equals('optimal'));
    });
  });
}
