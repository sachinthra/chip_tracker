import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/avatar_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/game_session.dart';
import '../../models/player.dart';
import '../../providers/game_providers.dart';
import '../../widgets/cash_out_dialog.dart';
import '../../widgets/player_avatar.dart';

/// Interactive "poker table": the Bank sits in the middle; players ring it.
/// - Drag the Bank onto a player to add a buy-in.
/// - Drag one player onto another to record a chip transfer (loan).
/// - Tap a player for details and quick actions.
class TableViewScreen extends ConsumerWidget {
  const TableViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeGameProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active game')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Table View')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Drag the Bank onto a player for a buy-in · drag a player onto '
              'another to move a buy-in · tap for details',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final center = Offset(size.width / 2, size.height / 2);
                final ringRadius = math.min(size.width, size.height) / 2 - 80;

                return Stack(
                  children: [
                    Center(
                      child: Container(
                        width: ringRadius * 2 + 24,
                        height: ringRadius * 2 + 24,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.4),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                    _bankNode(context, center),
                    for (var i = 0; i < session.players.length; i++)
                      _PlayerNode(
                        session: session,
                        player: session.players[i],
                        size: size,
                        center: center,
                        ringRadius: ringRadius,
                        angle: (2 * math.pi * i / session.players.length) -
                            math.pi / 2,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankNode(BuildContext context, Offset center) {
    const double half = 32;
    // The piggy icon speaks for itself — no "Bank" label needed.
    final bank = CircleAvatar(
      radius: 28,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: const Icon(Icons.savings_outlined, size: 28),
    );

    return Positioned(
      left: center.dx - half,
      top: center.dy - half,
      width: half * 2,
      child: Draggable<_DragPayload>(
        data: const _DragPayload.bank(),
        feedback: const _DragChip(icon: Icons.savings, label: 'Buy-in'),
        childWhenDragging: Opacity(opacity: 0.4, child: bank),
        child: bank,
      ),
    );
  }
}

/// Marks what is being dragged: the Bank, or a specific player.
class _DragPayload {
  final bool isBank;
  final Player? player;
  const _DragPayload.bank()
      : isBank = true,
        player = null;
  const _DragPayload.player(this.player) : isBank = false;
}

class _DragChip extends StatelessWidget {
  const _DragChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      ),
    );
  }
}

class _PlayerNode extends ConsumerWidget {
  const _PlayerNode({
    required this.session,
    required this.player,
    required this.size,
    required this.center,
    required this.ringRadius,
    required this.angle,
  });

  final GameSession session;
  final Player player;
  final Size size;
  final Offset center;
  final double ringRadius;
  final double angle;

  static const double _nodeWidth = 112;
  static const double _avatarRadius = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dx = center.dx + ringRadius * math.cos(angle);
    final dy = center.dy + ringRadius * math.sin(angle);
    final hasCashedOut = session.hasCashedOut(player.id);
    final net = session.netResultFor(player.id);
    final netColor = net >= 0 ? Colors.green[700] : Colors.red[700];
    final subtitle = hasCashedOut
        ? '${net >= 0 ? '+' : '-'}'
            '${CurrencyFormatter.format(net.abs(), currencyCode: session.currencyCode)}'
        : '${session.currentChipStack(player.id)} chips';

    final labelBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        _BuyInPips(
          count: session.totalBuyInChips(player.id) ~/ session.chipsPerBuyIn,
          color: AvatarColors.fromHex(player.avatarColorHex),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: hasCashedOut ? netColor : null,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );

    final avatar = GestureDetector(
      onTap: () => _showDetails(context, ref),
      child: Draggable<_DragPayload>(
        data: _DragPayload.player(player),
        feedback: _DragChip(icon: Icons.person, label: player.name),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: PlayerAvatar(player: player, radius: _avatarRadius),
        ),
        child: PlayerAvatar(player: player, radius: _avatarRadius),
      ),
    );

    // Labels sit OUTSIDE the ring: above the avatar for top-half seats, below
    // for bottom-half — so they never overlap the Bank in the middle.
    final isTopHalf = math.sin(angle) < 0;
    final node = Column(
      mainAxisSize: MainAxisSize.min,
      children: isTopHalf
          ? [labelBlock, const SizedBox(height: 2), avatar]
          : [avatar, const SizedBox(height: 2), labelBlock],
    );

    return Positioned(
      left: dx - _nodeWidth / 2,
      top: isTopHalf ? null : dy - _avatarRadius,
      bottom: isTopHalf ? size.height - (dy + _avatarRadius) : null,
      width: _nodeWidth,
      child: DragTarget<_DragPayload>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          return data.isBank || data.player?.id != player.id;
        },
        onAcceptWithDetails: (details) =>
            _onDrop(context, ref, details.data, details.offset),
        builder: (context, candidate, rejected) {
          final highlighted = candidate.isNotEmpty;
          return AnimatedScale(
            scale: highlighted ? 1.1 : 1,
            duration: const Duration(milliseconds: 120),
            child: node,
          );
        },
      ),
    );
  }

  void _onDrop(
    BuildContext context,
    WidgetRef ref,
    _DragPayload data,
    Offset dropGlobal,
  ) {
    if (data.isBank) {
      HapticFeedback.lightImpact();
      ref.read(activeGameProvider.notifier).recordBuyIn(player.id);
      _showChipFly(context, dropGlobal, '+${session.chipsPerBuyIn}');
    } else if (data.player != null) {
      _confirmTransfer(context, ref, from: data.player!, to: player);
    }
  }

  /// Floats a "+chips" badge up from [globalOffset] and fades it out.
  void _showChipFly(BuildContext context, Offset globalOffset, String label) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: globalOffset.dx - 24,
        top: globalOffset.dy - 24,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            builder: (context, t, child) => Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, -44 * t), child: child),
            ),
            child: Material(
              color: Colors.transparent,
              child: Chip(
                avatar: const Icon(Icons.paid, size: 18),
                label: Text(label),
                backgroundColor: Colors.green.shade100,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 720), entry.remove);
  }

  Future<void> _confirmTransfer(
    BuildContext context,
    WidgetRef ref, {
    required Player from,
    required Player to,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move a buy-in'),
        content: Text(
          'Move one ${session.chipsPerBuyIn}-chip buy-in from ${from.name} '
          'to ${to.name}?\n\n'
          '${from.name} drops one buy-in, ${to.name} gains one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final moved =
          ref.read(activeGameProvider.notifier).moveBuyIn(from.id, to.id);
      if (moved) {
        HapticFeedback.lightImpact();
        if (!context.mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          _showChipFly(
            context,
            box.localToGlobal(box.size.center(Offset.zero)),
            '+${session.chipsPerBuyIn}',
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${from.name} has no buy-in left to give — have ${to.name} '
              'take a buy-in from the Bank instead.',
            ),
          ),
        );
      }
    }
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final buyInCount =
            session.totalBuyInChips(player.id) ~/ session.chipsPerBuyIn;
        final hasCashedOut = session.hasCashedOut(player.id);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: PlayerAvatar(player: player, radius: 20),
                title: Text(player.name),
                subtitle: Text(
                  '$buyInCount buy-ins · ${session.currentChipStack(player.id)} chips on table',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text('Add a buy-in (+${session.chipsPerBuyIn})'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(activeGameProvider.notifier).recordBuyIn(player.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(hasCashedOut
                    ? 'Edit final chip count'
                    : 'Enter final chip count (cash-out)'),
                subtitle: hasCashedOut
                    ? Text('${session.totalCashOutChips(player.id)} chips')
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _cashOutDialog(context, ref);
                },
              ),
              if (hasCashedOut)
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: const Text('Still playing (clear cash-out)'),
                  onTap: () {
                    ref.read(activeGameProvider.notifier).clearCashOut(player.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cashOutDialog(BuildContext context, WidgetRef ref) async {
    final chips = await showDialog<int>(
      context: context,
      builder: (_) => CashOutDialog(
        playerName: player.name,
        initialChips: session.hasCashedOut(player.id)
            ? session.totalCashOutChips(player.id)
            : null,
      ),
    );
    if (chips != null) {
      ref.read(activeGameProvider.notifier).recordCashOut(player.id, chips);
    }
  }
}

/// Small chip dots under an avatar showing how many buy-ins a player has taken.
class _BuyInPips extends StatelessWidget {
  const _BuyInPips({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox(height: 4);
    final shown = count.clamp(0, 6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < shown; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          if (count > 6)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text('+${count - 6}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
