import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bustan_amari/domain/repositories/i_device_token_repository.dart';

class SupabaseDeviceTokenRepository implements IDeviceTokenRepository {
  final SupabaseClient _client;

  SupabaseDeviceTokenRepository(this._client);

  @override
  Future<void> upsertToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    await _client.from('device_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,platform',
    );
  }

  @override
  Future<void> deleteTokensForUser({required String userId}) async {
    await _client.from('device_tokens').delete().eq('user_id', userId);
  }
}
