import 'package:flutter/material.dart';

import '../core/utils/currency_formatter.dart';

/// Compact one-line balance summary pinned under an AppBar (via `bottom:`) so
/// it stays visible while the screen's body scrolls.
class GameStatsBar extends StatelessWidget implements PreferredSizeWidget {
  const GameStatsBar({
    super.key,
    required this.totalProfit,
    required this.isBalanced,
    required this.diffChips,
    required this.currencyCode,
  });

  final double totalProfit;
  final bool isBalanced;
  final int diffChips;
  final String currencyCode;

  @override
  Size get preferredSize => const Size.fromHeight(38);

  @override
  Widget build(BuildContext context) {
    final statusColor = isBalanced ? Colors.green : Colors.red;
    return Container(
      color: statusColor.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle : Icons.warning_amber,
            size: 16,
            color: statusColor[800],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isBalanced
                  ? 'Balanced — ready to settle'
                  : 'Off by ${diffChips.abs()} chips',
              style: TextStyle(color: statusColor[800], fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Profit: ${CurrencyFormatter.format(totalProfit, currencyCode: currencyCode)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
