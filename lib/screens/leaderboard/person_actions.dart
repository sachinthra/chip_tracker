import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/avatar_colors.dart';
import '../../models/leaderboard_entry.dart';
import '../../providers/people_providers.dart';

/// Rename / combine / recolor actions for a leaderboard person, shared by the
/// leaderboard list and the per-person details screen.
class PersonActions {
  const PersonActions._();

  static void showSheet(
    BuildContext context,
    WidgetRef ref,
    LeaderboardEntry entry,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                rename(context, ref, entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.merge_type),
              title: const Text('Combine with another person'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                merge(context, ref, entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Change color'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                changeColor(context, ref, entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> rename(
    BuildContext context,
    WidgetRef ref,
    LeaderboardEntry entry,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: entry.displayName),
    );
    if (name == null || name.isEmpty) return;

    // If the new name already belongs to a different person, offer to combine
    // instead of creating a conflicting duplicate.
    final clash = ref.read(leaderboardProvider).where((e) =>
        e.key != entry.key &&
        e.displayName.toLowerCase() == name.toLowerCase());
    if (clash.isNotEmpty) {
      if (!context.mounted) return;
      final target = clash.first;
      final combine = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Combine with "${target.displayName}"?'),
          content: Text(
            'A person named "${target.displayName}" already exists. Combine '
            '"${entry.displayName}" into them? Their games will be merged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Combine'),
            ),
          ],
        ),
      );
      if (combine == true) {
        ref.read(profilesProvider.notifier).merge(
              targetKey: target.key,
              targetDisplayName: target.displayName,
              targetColorHex: target.colorHex,
              sourceKey: entry.key,
              sourceDisplayName: entry.displayName,
              sourceColorHex: entry.colorHex,
            );
      }
      return;
    }

    ref.read(profilesProvider.notifier).rename(entry.key, name);
  }

  static Future<void> merge(
    BuildContext context,
    WidgetRef ref,
    LeaderboardEntry entry,
  ) async {
    final others =
        ref.read(leaderboardProvider).where((e) => e.key != entry.key).toList();
    if (others.isEmpty) return;
    final target = await showDialog<LeaderboardEntry>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Combine "${entry.displayName}" into…'),
        children: [
          for (final other in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(other),
              child: Text(other.displayName),
            ),
        ],
      ),
    );
    if (target != null) {
      ref.read(profilesProvider.notifier).merge(
            targetKey: target.key,
            targetDisplayName: target.displayName,
            targetColorHex: target.colorHex,
            sourceKey: entry.key,
            sourceDisplayName: entry.displayName,
            sourceColorHex: entry.colorHex,
          );
    }
  }

  static Future<void> changeColor(
    BuildContext context,
    WidgetRef ref,
    LeaderboardEntry entry,
  ) async {
    final color = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in AvatarColors.palette)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(hex),
                child: CircleAvatar(
                  backgroundColor: AvatarColors.fromHex(hex),
                  radius: 18,
                ),
              ),
          ],
        ),
      ),
    );
    if (color != null) {
      ref.read(profilesProvider.notifier).setColor(
            entry.key,
            color,
            displayName: entry.displayName,
          );
    }
  }
}

/// Owns its own controller so it's disposed only after the route is fully
/// removed (avoids the "_dependents.isEmpty" assertion from early disposal).
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename person'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
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
