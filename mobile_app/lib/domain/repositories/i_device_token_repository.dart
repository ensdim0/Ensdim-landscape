/// Contract for persisting and removing FCM device tokens.
abstract class IDeviceTokenRepository {
  Future<void> upsertToken({
    required String userId,
    required String token,
    required String platform,
  });

  Future<void> deleteTokensForUser({required String userId});
}
