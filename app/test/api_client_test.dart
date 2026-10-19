import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saath/api/api_client.dart';
import 'package:saath/api/models.dart';

ApiClient clientWith(MockClientHandler handler, {Duration? timeout}) => ApiClient(
      baseUrl: 'http://test',
      token: 'tok',
      httpClient: MockClient(handler),
      timeout: timeout ?? const Duration(seconds: 1),
    );

void main() {
  test('sends bearer token and parses today game', () async {
    final api = clientWith((req) async {
      expect(req.headers['Authorization'], 'Bearer tok');
      return http.Response(
        jsonEncode({
          'day': '2026-10-19',
          'questions': [
            {'id': 'foo-01', 'tag': 'food', 'prompt': 'Chai or coffee?', 'a': 'Chai', 'b': 'Coffee'}
          ],
          'i_answered': false,
          'partner_answered': true,
        }),
        200,
      );
    });

    final game = await api.today();
    expect(game.questions.single.label('b'), 'Coffee');
    expect(game.partnerAnswered, isTrue);
  });

  test('surfaces server detail message', () async {
    final api = clientWith((_) async =>
        http.Response(jsonEncode({'detail': 'this code is already used'}), 409));

    expect(
      api.joinCouple('ABC234'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 409)
          .having((e) => e.friendly, 'friendly', 'this code is already used')),
    );
  });

  test('reads the first message from a validation error list', () async {
    final api = clientWith((_) async => http.Response(
        jsonEncode({
          'detail': [
            {'msg': 'name too long'}
          ]
        }),
        422));

    expect(api.signUp('x'), throwsA(isA<ApiException>().having((e) => e.message, 'm', 'name too long')));
  });

  test('timeout becomes a network error', () async {
    final api = clientWith(
      (_) => Completer<http.Response>().future, // never completes
      timeout: const Duration(milliseconds: 50),
    );

    expect(api.me(), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
  });

  test('myCouple returns null when not paired', () async {
    final api = clientWith((_) async => http.Response(jsonEncode({'detail': 'not paired yet'}), 404));
    expect(await api.myCouple(), isNull);
  });

  test('submit sends every answer', () async {
    late Map<String, dynamic> sent;
    final api = clientWith((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'state': 'waiting_for_partner', 'day': '2026-10-19'}), 200);
    });

    final r = await api.submit({'foo-01': const MyAnswer('a', 'b')});
    expect(r.state, ResultState.waitingForPartner);
    expect(sent['answers'], [
      {'question_id': 'foo-01', 'mine': 'a', 'guess': 'b'}
    ]);
  });
}
