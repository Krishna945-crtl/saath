import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../config.dart';

const _tokenKey = 'saath.token';

/// Holds the auth token. null = not signed up on this device yet.
class SessionNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> signIn(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    state = AsyncData(token);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    state = const AsyncData(null);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, String?>(SessionNotifier.new);

final apiProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(sessionProvider).valueOrNull;
  return ApiClient(baseUrl: apiUrl, token: token);
});

final coupleProvider =
    FutureProvider<CoupleInfo?>((ref) => ref.watch(apiProvider).myCouple());

final todayProvider = FutureProvider.autoDispose<TodayGame>(
    (ref) => ref.watch(apiProvider).today());

final resultProvider = FutureProvider.autoDispose<GameResult>(
    (ref) => ref.watch(apiProvider).result());
