import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/splitwise/splitwise_service.dart';
import 'game_providers.dart';

/// The linked Splitwise account (the host who connected their token).
class SplitwiseAccount {
  final String id;
  final String name;

  const SplitwiseAccount({required this.id, required this.name});

  factory SplitwiseAccount.fromUser(Map<String, dynamic> user) {
    final first = (user['first_name'] as String?)?.trim() ?? '';
    final last = (user['last_name'] as String?)?.trim() ?? '';
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    return SplitwiseAccount(
      id: user['id'].toString(),
      name: name.isEmpty ? 'Splitwise user' : name,
    );
  }
}

/// Connection state for Splitwise: `null` data means "not connected".
/// Everything else in the app works whether or not this is connected.
class SplitwiseConnection extends AsyncNotifier<SplitwiseAccount?> {
  SplitwiseService get _service => ref.read(splitwiseServiceProvider);

  @override
  Future<SplitwiseAccount?> build() async {
    if (!await _service.hasApiToken()) return null;
    try {
      return SplitwiseAccount.fromUser(await _service.getCurrentUser());
    } catch (_) {
      // Token present but invalid/expired — treat as disconnected.
      return null;
    }
  }

  /// Validates [token] by fetching the current user; only persists it on
  /// success. Throws (surfaced via [state].error) if the token is rejected.
  Future<void> connect(String token) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _service.setApiToken(token);
      try {
        return SplitwiseAccount.fromUser(await _service.getCurrentUser());
      } catch (e) {
        await _service.clearApiToken();
        rethrow;
      }
    });
  }

  Future<void> disconnect() async {
    await _service.clearApiToken();
    state = const AsyncData(null);
  }
}

final splitwiseConnectionProvider =
    AsyncNotifierProvider<SplitwiseConnection, SplitwiseAccount?>(
  SplitwiseConnection.new,
);
