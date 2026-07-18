import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bustan_amari/domain/entities/app_notification.dart';
import 'package:bustan_amari/domain/repositories/i_notification_repository.dart';

class SupabaseNotificationRepository implements INotificationRepository {
  final SupabaseClient _client;

  SupabaseNotificationRepository(this._client);

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];

    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map(_map).toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final uid = _uid;
    if (uid == null) return 0;

    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .eq('read', false);

    return (data as List).length;
  }

  @override
  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;

    await _client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', uid)
        .eq('read', false);
  }

  @override
  Stream<void> watchNewNotifications() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    late StreamController<void> controller;
    RealtimeChannel? channel;

    controller = StreamController<void>(
      onListen: () {
        channel = _client.channel('db-notifications-$uid');
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () {
        if (channel != null) _client.removeChannel(channel!);
        controller.close();
      },
    );

    return controller.stream;
  }

  AppNotification _map(dynamic row) => AppNotification(
        id: row['id'] as String,
        userId: row['user_id'] as String? ?? '',
        title: row['title'] as String,
        body: row['body'] as String?,
        isRead: row['read'] as bool? ?? false,
        meta: (row['meta'] as Map<String, dynamic>?) ?? {},
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
