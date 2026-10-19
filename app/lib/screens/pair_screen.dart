import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/providers.dart';

class PairScreen extends ConsumerStatefulWidget {
  /// null = hasn't created a code yet. Non-null = waiting for partner to join.
  final CoupleInfo? couple;
  const PairScreen({super.key, required this.couple});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _startPollingIfWaiting();
  }

  @override
  void didUpdateWidget(PairScreen old) {
    super.didUpdateWidget(old);
    _startPollingIfWaiting();
  }

  // While my code is out there, quietly check every few seconds so the
  // screen moves on by itself the moment my partner joins.
  void _startPollingIfWaiting() {
    if (widget.couple == null || _poll != null) return;
    _poll = Timer.periodic(
        const Duration(seconds: 5), (_) => ref.invalidate(coupleProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(ApiClient api) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(apiProvider));
      ref.invalidate(coupleProvider);
    } on ApiException catch (e) {
      setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final couple = widget.couple;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Text('Find your person', style: text.headlineMedium),
        const SizedBox(height: 8),
        const Text('One of you shares a code, the other enters it.'),
        const SizedBox(height: 32),
        if (couple == null)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run((api) => api.createCouple()),
            icon: const Icon(Icons.favorite_border_rounded),
            label: const Text('Get my invite code'),
          )
        else
          _CodeCard(code: couple.inviteCode),
        const SizedBox(height: 32),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 24),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: "Partner's code",
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: (_busy || _code.text.trim().length < 6)
              ? null
              : () => _run((api) => api.joinCouple(_code.text.trim())),
          child: const Text('Join'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  const _CodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Send this to your partner', style: text.labelLarge),
            const SizedBox(height: 12),
            SelectableText(code,
                style: text.displaySmall?.copyWith(letterSpacing: 6)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Code copied')));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Waiting for them to join…', style: text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
