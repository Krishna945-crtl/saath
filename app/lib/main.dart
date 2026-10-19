import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'screens/game_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pair_screen.dart';
import 'state/providers.dart';
import 'widgets/state_views.dart';

void main() => runApp(const ProviderScope(child: SaathApp()));

class SaathApp extends StatelessWidget {
  const SaathApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Most play is at night, so dark is the default, not an afterthought
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE85D75),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Saath',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: const RootGate(),
    );
  }
}

/// Decides which screen to show: sign up -> pair -> play.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    final Widget content = session.when(
      loading: () => const LoadingView(),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(sessionProvider)),
      data: (token) {
        if (token == null) return const OnboardingScreen();

        final couple = ref.watch(coupleProvider);
        return couple.when(
          loading: () => const LoadingView(),
          error: (e, _) {
            // Token got wiped server-side (fresh DB etc.) — start over cleanly
            if (e is ApiException && e.isUnauthorized) {
              Future.microtask(
                  () => ref.read(sessionProvider.notifier).signOut());
              return const LoadingView();
            }
            return ErrorView(
                error: e, onRetry: () => ref.invalidate(coupleProvider));
          },
          data: (c) => (c != null && c.complete)
              ? const GameScreen()
              : PairScreen(couple: c),
        );
      },
    );

    return Scaffold(
      body: SafeArea(
        // Phone-width column even on a laptop, so nothing stretches edge to edge
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: content,
          ),
        ),
      ),
    );
  }
}
