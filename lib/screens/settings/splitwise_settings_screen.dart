import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/splitwise_providers.dart';

/// Connect or disconnect the host's Splitwise account via a personal API key.
/// Splitwise stays entirely optional — the app works without it.
class SplitwiseSettingsScreen extends ConsumerStatefulWidget {
  const SplitwiseSettingsScreen({super.key});

  @override
  ConsumerState<SplitwiseSettingsScreen> createState() =>
      _SplitwiseSettingsScreenState();
}

class _SplitwiseSettingsScreenState
    extends ConsumerState<SplitwiseSettingsScreen> {
  final _tokenController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    setState(() => _submitting = true);
    await ref.read(splitwiseConnectionProvider.notifier).connect(token);
    if (!mounted) return;
    setState(() => _submitting = false);
    final state = ref.read(splitwiseConnectionProvider);
    if (state.hasError || state.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect — check the token.')),
      );
    } else {
      _tokenController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected as ${state.value!.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(splitwiseConnectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Splitwise')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          connection.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (_, _) => _disconnectedView(),
            data: (account) =>
                account == null ? _disconnectedView() : _connectedView(account),
          ),
        ],
      ),
    );
  }

  Widget _connectedView(SplitwiseAccount account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text('Connected as ${account.name}'),
          subtitle: const Text('Settlements can be pushed to Splitwise.'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Disconnect'),
          onPressed: () =>
              ref.read(splitwiseConnectionProvider.notifier).disconnect(),
        ),
      ],
    );
  }

  Widget _disconnectedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Splitwise (optional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Paste a personal API key from secure.splitwise.com/apps '
          '(Register your app → generate an API key). Only the host needs '
          'to connect. The app works fully without this.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tokenController,
          decoration: InputDecoration(
            labelText: 'Splitwise API key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Paste',
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _tokenController.text = data!.text!.trim();
                }
              },
            ),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitting ? null : _connect,
          child: _submitting
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Connect'),
        ),
      ],
    );
  }
}
