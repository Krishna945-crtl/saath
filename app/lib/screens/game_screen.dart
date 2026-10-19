import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/providers.dart';
import '../widgets/state_views.dart';
import 'result_screen.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final partner =
        ref.watch(coupleProvider).valueOrNull?.partnerName ?? 'your partner';

    return today.when(
      loading: () => const LoadingView(label: "Getting tonight's game…"),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(todayProvider)),
      data: (game) {
        if (game.questions.isEmpty) {
          return EmptyView(
            icon: Icons.nights_stay_rounded,
            title: 'No game right now',
            subtitle: 'Check back in a bit.',
            action: OutlinedButton(
              onPressed: () => ref.invalidate(todayProvider),
              child: const Text('Refresh'),
            ),
          );
        }
        if (game.iAnswered) return const ResultScreen();
        return _Play(game: game, partner: partner);
      },
    );
  }
}

/// Five questions, each in two steps: pick for yourself, then guess your partner.
class _Play extends ConsumerStatefulWidget {
  final TodayGame game;
  final String partner;
  const _Play({required this.game, required this.partner});

  @override
  ConsumerState<_Play> createState() => _PlayState();
}

class _PlayState extends ConsumerState<_Play> {
  final _mine = <String, String>{};
  final _guess = <String, String>{};
  int _index = 0;
  bool _guessing = false; // false = picking for me, true = guessing partner
  bool _submitting = false;

  List<Question> get _qs => widget.game.questions;
  bool get _done => _guess.length == _qs.length;

  void _choose(String choice) {
    final q = _qs[_index];
    setState(() {
      if (!_guessing) {
        _mine[q.id] = choice;
        _guessing = true;
      } else {
        _guess[q.id] = choice;
        _guessing = false;
        if (_index < _qs.length - 1) _index++;
      }
    });
  }

  void _back() {
    setState(() {
      if (_guessing) {
        _guessing = false;
      } else if (_index > 0) {
        _index--;
        _guessing = true;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final answers = {
      for (final q in _qs) q.id: MyAnswer(_mine[q.id]!, _guess[q.id]!)
    };

    try {
      await ref.read(apiProvider).submit(answers);
      // Server is the source of truth for what to show next
      ref.invalidate(todayProvider);
      ref.invalidate(coupleProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Answers stay in memory, so "Retry" resends the exact same payload.
      // The server treats an identical resend as a no-op, so double-taps are safe.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.friendly),
          action: SnackBarAction(label: 'Retry', onPressed: _submit),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_done) {
      return EmptyView(
        icon: Icons.favorite_rounded,
        title: 'All done!',
        subtitle:
            "Lock in your answers and see how well you know ${widget.partner}.",
        action: Column(
          children: [
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lock in'),
            ),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _guess.remove(_qs.last.id);
                        _guessing = true;
                      }),
              child: const Text('Go back'),
            ),
          ],
        ),
      );
    }

    final q = _qs[_index];
    final selected = _guessing ? _guess[q.id] : _mine[q.id];
    final step = _index * 2 + (_guessing ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconButton(
              onPressed: (step == 0) ? null : _back,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            Expanded(
                child: LinearProgressIndicator(value: step / (_qs.length * 2))),
            const SizedBox(width: 12),
            Text('${_index + 1}/${_qs.length}'),
          ]),
          const Spacer(),
          Text(
            _guessing ? 'What would ${widget.partner} pick?' : 'Your pick',
            style: text.labelLarge?.copyWith(color: scheme.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(q.prompt,
              style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          _OptionButton(
              label: q.a, selected: selected == 'a', onTap: () => _choose('a')),
          const SizedBox(height: 12),
          _OptionButton(
              label: q.b, selected: selected == 'b', onTap: () => _choose('b')),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 20)),
      textStyle:
          WidgetStatePropertyAll(Theme.of(context).textTheme.titleMedium),
    );
    return selected
        ? FilledButton(style: style, onPressed: onTap, child: Text(label))
        : OutlinedButton(style: style, onPressed: onTap, child: Text(label));
  }
}
