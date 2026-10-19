import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  /// null means we never got a response (offline, timeout, DNS...)
  final int? status;
  final String message;

  const ApiException(this.status, this.message);

  bool get isNetwork => status == null;
  bool get isUnauthorized => status == 401;

  /// Text that's safe to show a user. Server messages are short and
  /// written for humans, network errors get a friendlier line.
  String get friendly {
    if (isNetwork)
      return "Couldn't reach Saath. Check your internet and try again.";
    if (status! >= 500) return 'Something broke on our side. Please try again.';
    return message;
  }

  @override
  String toString() => 'ApiException($status, $message)';
}

class ApiClient {
  final String baseUrl;
  final String? token;
  final http.Client _http;
  final Duration timeout;

  ApiClient({
    required this.baseUrl,
    this.token,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  // ---- users ----

  Future<({String token, Me me})> signUp(String name) async {
    final j = await _send('POST', '/users', body: {'name': name})
        as Map<String, dynamic>;
    return (token: j['token'] as String, me: Me.fromJson(j));
  }

  Future<Me> me() async => Me.fromJson(await _send('GET', '/me'));

  Future<List<String>> tags() async =>
      List<String>.from(await _send('GET', '/tags'));

  Future<Me> saveLikes(List<String> tags) async =>
      Me.fromJson(await _send('PUT', '/me/likes', body: {'tags': tags}));

  // ---- couples ----

  Future<CoupleInfo> createCouple() async =>
      CoupleInfo.fromJson(await _send('POST', '/couples'));

  Future<CoupleInfo> joinCouple(String code) async => CoupleInfo.fromJson(
      await _send('POST', '/couples/join', body: {'code': code}));

  /// Returns null when the user hasn't created or joined a couple yet.
  Future<CoupleInfo?> myCouple() async {
    try {
      return CoupleInfo.fromJson(await _send('GET', '/couples/me'));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  // ---- game ----

  Future<TodayGame> today() async =>
      TodayGame.fromJson(await _send('GET', '/games/today'));

  Future<GameResult> result() async =>
      GameResult.fromJson(await _send('GET', '/games/today/result'));

  Future<GameResult> submit(Map<String, MyAnswer> answers) async {
    final body = {
      'answers': [for (final e in answers.entries) e.value.toJson(e.key)],
    };
    return GameResult.fromJson(
        await _send('POST', '/games/today/answers', body: body));
  }

  // ---- plumbing ----

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(timeout));
    } on TimeoutException {
      throw const ApiException(null, 'timeout');
    } on http.ClientException catch (e) {
      throw ApiException(null, e.message);
    }

    final decoded =
        res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw ApiException(res.statusCode,
        _detail(decoded) ?? 'Request failed (${res.statusCode})');
  }

  /// FastAPI sends {"detail": "..."} for our errors, and
  /// {"detail": [{"msg": ...}, ...]} for validation errors.
  static String? _detail(dynamic body) {
    if (body is! Map) return null;
    final d = body['detail'];
    if (d is String) return d;
    if (d is List && d.isNotEmpty && d.first is Map)
      return d.first['msg']?.toString();
    return null;
  }
}
