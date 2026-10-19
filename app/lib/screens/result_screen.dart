import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../state/providers.dart';
import '../widgets/state_views.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultProvider);
    final partner =
        ref.watch(coupleProvider).valueOrNull?.partnerName ?? 'Your partner';

    Future<void> refresh() async {
      try {
        ref.invalidate(resultProvider);
        await ref.read(resultProvider.future);
      } catch (_) {
        // the error state renders its own retry button
      }
    }

    return result.when(
      loading: () => const LoadingView(),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(resultProvider)),
      data: (r) => RefreshIndicator(
        onRefresh: refresh,
        // ListView so pull-to-refresh works even on the short "waiting" state
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: switch (r.state) {
            ResultState.ready => _ready(context, r, partner),
            ResultState.waitingForPartner => [
                const SizedBox(height: 120),
                EmptyView(
                  icon: Icons.hourglass_bottom_rounded,
                  title: 'Waiting for $partner',
                  subtitle:
                      "Your answers are locked in. Nudge them!\nPull down to check again.",
                ),
              ],
            // Shouldn't happen (GameScreen only shows us after I answered),
            // but if it does, send them back to play instead of a blank screen.
            ResultState.waitingForMe => [
                const SizedBox(height: 120),
                EmptyView(
                  icon: Icons.play_circle_outline_rounded,
                  title: "You haven't played yet",
                  action: FilledButton(
                    onPressed: () => ref.invalidate(todayProvider),
                    child: const Text('Play now'),
                  ),
                ),
              ],
          },
        ),
      ),
    );
  }

  List<Widget> _ready(BuildContext context, GameResult r, String partner) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return [
      const SizedBox(height: 16),
      Text("Tonight's score",
          style: text.labelLarge, textAlign: TextAlign.center),
      Text('${r.score} / ${r.outOf}',
          style: text.displayMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(
        'You picked the same thing ${r.samePicks} times',
        style: text.bodyMedium,
        textAlign: TextAlign.center,
      ),
      if (r.streak > 0) ...[
        const SizedBox(height: 12),
        Center(
          child: Chip(
            avatar: const Icon(Icons.local_fire_department_rounded, size: 18),
            label: Text('${r.streak}-day streak'),
          ),
        ),
      ],
      const SizedBox(height: 24),
      for (final item in r.items)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.question.prompt, style: text.titleMedium),
                const SizedBox(height: 8),
                _Line(
                    who: 'You',
                    pick: item.question.label(item.myPick),
                    right: item.partnerGuessedRight),
                _Line(
                    who: partner,
                    pick: item.question.label(item.partnerPick),
                    right: item.iGuessedRight),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        '✓ means the other person guessed it right',
        style: text.bodySmall?.copyWith(color: scheme.outline),
        textAlign: TextAlign.center,
      ),
    ];
  }
}

class _Line extends StatelessWidget {
  final String who;
  final String pick;
  final bool right;
  const _Line({required this.who, required this.pick, required this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 90, child: Text(who, overflow: TextOverflow.ellipsis)),
        Expanded(
            child: Text(pick,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Icon(
          right ? Icons.check_circle_rounded : Icons.cancel_outlined,
          size: 18,
          color: right
              ? Colors.greenAccent
              : Theme.of(context).colorScheme.outline,
        ),
      ]),
    );
  }
}
