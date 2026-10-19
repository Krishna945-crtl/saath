import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../state/providers.dart';

/// Name + pick a few topics you like. Topics steer which questions show up.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Known up front so onboarding works before we have a token
  static const _topics = [
    'deep',
    'food',
    'habits',
    'movies',
    'music',
    'travel'
  ];

  final _name = TextEditingController();
  final _picked = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSubmit => _name.text.trim().isNotEmpty && !_saving;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final signUp = await ApiClient(baseUrl: apiUrl).signUp(_name.text.trim());
      if (_picked.isNotEmpty) {
        await ApiClient(baseUrl: apiUrl, token: signUp.token)
            .saveLikes(_picked.toList());
      }
      await ref.read(sessionProvider.notifier).signIn(signUp.token);
    } on ApiException catch (e) {
      setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Text('Saath', style: text.displaySmall),
        const SizedBox(height: 8),
        Text('One small game a day, for the two of you.',
            style: text.bodyLarge),
        const SizedBox(height: 40),
        TextField(
          controller: _name,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'What should your partner see you as?',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Pick topics you enjoy (optional)', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _topics)
              FilterChip(
                label: Text(t[0].toUpperCase() + t.substring(1)),
                selected: _picked.contains(t),
                onSelected: (on) =>
                    setState(() => on ? _picked.add(t) : _picked.remove(t)),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
      ],
    );
  }
}
