import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:ensdim_landscape/core/security/secure_logger.dart';
import 'package:ensdim_landscape/domain/repositories/i_device_token_repository.dart';

// ── Android notification channels ───────────────────────────────────────────
const _kChannelId = 'line_assignments';
const _kChannelName = 'تعيينات الخطوط';
const _kPaymentChannelId = 'payment_notifications';
const _kPaymentChannelName = 'إشعارات الدفع';

/// Must be a top-level function — FCM background isolate requires it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  IDeviceTokenRepository? _tokenRepo;
  String? _currentUserId;

  /// Pending deep-link data set when user taps an FCM notification.
  /// Keys vary by type:
  ///   standalone_task_assigned → {'type': '...', 'taskId': '...'}
  ///   client_comment           → {'type': '...', 'visitId': '...', 'contractId': '...'}
  Map<String, String>? _pendingNav;
  Map<String, String>? get pendingNav => _pendingNav;
  void clearPendingNav() => _pendingNav = null;

  // Keep old accessor for backwards compat with existing dashboard code.
  String? get pendingTaskId => _pendingNav?['taskId'];
  void clearPendingTaskId() => _pendingNav = null;

  /// Fires whenever a foreground FCM message arrives — used to refresh badge.
  final _foregroundMessageController = StreamController<void>.broadcast();
  Stream<void> get onForegroundMessage => _foregroundMessageController.stream;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> initialize(IDeviceTokenRepository tokenRepo) async {
    _tokenRepo = tokenRepo;
    await _createAndroidChannel();
    await _requestPermission();
    _listenForeground();
    _listenTaps();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // App opened by tapping a terminated-state notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  /// Upload the FCM token to Supabase after a successful login.
  Future<void> registerToken(String userId) async {
    _currentUserId = userId;
    try {
      final token = await _fcm.getToken();
      if (token != null) await _upsert(userId, token);

      _fcm.onTokenRefresh.listen((refreshed) async {
        if (_currentUserId != null) await _upsert(_currentUserId!, refreshed);
      });
    } catch (e) {
      SecureLogger.error('Notifications', 'فشل تسجيل رمز الإشعار', e);
      if (kDebugMode) debugPrint('[Notifications] token upsert detail: $e');
    }
  }

  /// Delete the token from Supabase and revoke it from FCM on logout.
  Future<void> clearToken(String userId) async {
    try {
      await _fcm.deleteToken();
      await _tokenRepo?.deleteTokensForUser(userId: userId);
    } catch (_) {}
    _currentUserId = null;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: settings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kPaymentChannelId,
        _kPaymentChannelName,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );
  }

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((message) {
      _foregroundMessageController.add(null);
      final n = message.notification;
      if (n == null) return;
      final type = message.data['type'] as String?;
      final isPayment = type != null &&
          (type == 'payment_request' ||
              type == 'payment_due_today' ||
              type == 'payment_due_1' ||
              type == 'payment_due_3' ||
              type == 'payment_late' ||
              type == 'payment_confirmed');
      final channelId = isPayment ? _kPaymentChannelId : _kChannelId;
      final channelName = isPayment ? _kPaymentChannelName : _kChannelName;
      _localNotifications.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
    });
  }

  /// Listens for taps on FCM notifications while app is in background.
  void _listenTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  void _handleTap(RemoteMessage message) {
    _applyNavData(message.data);
  }

  void _applyNavData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'standalone_task_assigned') {
      final taskId = data['taskId'] as String?;
      if (taskId != null) _pendingNav = {'type': type!, 'taskId': taskId};
    } else if (type == 'client_comment' || type == 'supervisor_note') {
      final visitId    = data['visitId']    as String?;
      final contractId = data['contractId'] as String?;
      if (visitId != null && contractId != null) {
        _pendingNav = {'type': type!, 'visitId': visitId, 'contractId': contractId};
      }
    } else if (type == 'payment_request' ||
        type == 'payment_due_today' ||
        type == 'payment_due_1' ||
        type == 'payment_due_3' ||
        type == 'payment_late' ||
        type == 'payment_confirmed') {
      final contractId = data['contractId'] as String?;
      final paymentId  = data['paymentId']  as String?;
      if (contractId != null) {
        _pendingNav = {
          'type': type!,
          'contractId': contractId,
          if (paymentId != null) 'paymentId': paymentId,
        };
      }
    }
  }

  /// Called when the user taps a local (foreground) notification.
  void _onLocalNotificationTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      _applyNavData(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Legacy plain taskId string
      _pendingNav = {'type': 'standalone_task_assigned', 'taskId': raw};
    }
  }

  Future<void> _upsert(String userId, String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    await _tokenRepo?.upsertToken(
      userId: userId,
      token: token,
      platform: platform,
    );
  }
}
