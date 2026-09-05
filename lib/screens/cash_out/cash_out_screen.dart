import 'package:flutter/material.dart';

/// End-of-night sliders per player, snapping to 100/500 chip increments,
/// with a live Net Profit/Loss indicator (green/red).
/// TODO: wire sliders to ActiveGameNotifier.recordCashOut.
class CashOutScreen extends StatelessWidget {
  const CashOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Out')),
      body: const Center(child: Text('Cash-out sliders coming soon')),
    );
  }
}
