import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin client for the Splitwise REST API (v3).
///
/// Auth is TODO: Splitwise supports either OAuth2 or a static API key issued
/// per-app from https://secure.splitwise.com/apps. Until we decide which one
/// to implement, [setApiToken] lets us bootstrap with a personal API key so
/// the rest of the app (group/friend lookups, expense creation) can be built
/// and tested end-to-end.
class SplitwiseService {
  SplitwiseService({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ??
            Dio(BaseOptions(baseUrl: 'https://secure.splitwise.com/api/v3.0')),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const _tokenKey = 'splitwise_api_token';

  Future<void> setApiToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<bool> hasApiToken() async {
    final token = await _secureStorage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> clearApiToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<Options> _authOptions() async {
    final token = await _secureStorage.read(key: _tokenKey);
    if (token == null) {
      throw StateError('No Splitwise API token set. Call setApiToken() first.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// The logged-in Splitwise user (used to confirm the linked account).
  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _dio.get(
      '/get_current_user',
      options: await _authOptions(),
    );
    return response.data['user'] as Map<String, dynamic>;
  }

  /// Groups the current user belongs to, used to pick a table's settlement group.
  Future<List<Map<String, dynamic>>> getGroups() async {
    final response = await _dio.get('/get_groups', options: await _authOptions());
    return List<Map<String, dynamic>>.from(response.data['groups'] as List);
  }

  /// Friends the current user can seat at the table (mapped to [Player]s).
  Future<List<Map<String, dynamic>>> getFriends() async {
    final response = await _dio.get('/get_friends', options: await _authOptions());
    return List<Map<String, dynamic>>.from(response.data['friends'] as List);
  }

  /// Pushes one simplified settlement transaction as a Splitwise expense:
  /// [paidByUserId] covers the full [amount], [owedByUserId] owes it back.
  Future<Map<String, dynamic>> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String currencyCode,
    required String paidByUserId,
    required String owedByUserId,
  }) async {
    final response = await _dio.post(
      '/create_expense',
      data: {
        'cost': amount.toStringAsFixed(2),
        'description': description,
        'currency_code': currencyCode,
        'group_id': groupId,
        'users__0__user_id': paidByUserId,
        'users__0__paid_share': amount.toStringAsFixed(2),
        'users__0__owed_share': '0.00',
        'users__1__user_id': owedByUserId,
        'users__1__paid_share': '0.00',
        'users__1__owed_share': amount.toStringAsFixed(2),
      },
      options: await _authOptions(),
    );
    return response.data as Map<String, dynamic>;
  }
}
