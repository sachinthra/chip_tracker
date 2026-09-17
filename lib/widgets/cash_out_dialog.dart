import 'package:flutter/material.dart';

/// Number-entry dialog for a player's final chip count. Owns its controller so
/// it's disposed only after the route is removed (avoids the
/// "_dependents.isEmpty" assertion). Returns the entered chip count, or null.
class CashOutDialog extends StatefulWidget {
  const CashOutDialog({
    super.key,
    required this.playerName,
    this.initialChips,
    this.remainingChips,
  });

  final String playerName;
  final int? initialChips;

  /// Chips still unaccounted for across the whole table (not yet cashed out),
  /// so the last player's count is easy to reconcile.
  final int? remainingChips;

  @override
  State<CashOutDialog> createState() => _CashOutDialogState();
}

class _CashOutDialogState extends State<CashOutDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialChips?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fill(int value) {
    _controller.value = TextEditingValue(
      text: value.toString(),
      selection: TextSelection.collapsed(offset: value.toString().length),
    );
  }

  void _submit() => Navigator.of(context).pop(int.tryParse(_controller.text.trim()));

  @override
  Widget build(BuildContext context) {
    final remaining = widget.remainingChips;
    return AlertDialog(
      title: Text('${widget.playerName} cash-out'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Final chip count',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (remaining != null) ...[
            const SizedBox(height: 12),
            ActionChip(
              avatar: const Icon(Icons.savings_outlined, size: 18),
              label: Text('Left on table $remaining'),
              onPressed: () => _fill(remaining),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to fill the chips still unaccounted for.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
