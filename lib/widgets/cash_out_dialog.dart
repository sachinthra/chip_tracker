import 'package:flutter/material.dart';

/// Number-entry dialog for a player's final chip count. Owns its controller so
/// it's disposed only after the route is removed (avoids the
/// "_dependents.isEmpty" assertion). Returns the entered chip count, or null.
class CashOutDialog extends StatefulWidget {
  const CashOutDialog({super.key, required this.playerName, this.initialChips});

  final String playerName;
  final int? initialChips;

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

  void _submit() => Navigator.of(context).pop(int.tryParse(_controller.text.trim()));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.playerName} cash-out'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Final chip count',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
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
