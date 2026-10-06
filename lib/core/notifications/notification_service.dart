import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Must be top-level (or static) with this exact pragma — FCM runs it in its
/// own background isolate, which starts from scratch and needs Firebase
/// re-initialised. Android/iOS already draw the system notification from the
/// message's own `notification` block in this state, so there is nothing else
/// to do here; it exists so a future data-only push has somewhere to go.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Booking updates',
  description: 'Booking accepted, job progress and payment updates',
  importance: Importance.high,
);

/// Push notifications for booking/job status changes, via Firebase Cloud
/// Messaging. Every step is wrapped so a missing
/// `android/app/google-services.json` (Firebase not set up yet for this build)
/// leaves the rest of the app working exactly as before, just without pushes —
/// the same "degrade silently" rule the backend's FcmService follows.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  String? _token;
  String? get token => _token;

  /// Called with the token once available, and again whenever FCM rotates it.
  void Function(String token)? onToken;

  /// Called with the message's data payload (all string values) when a
  /// notification is tapped — foreground (local notification), background, or
  /// cold-start (terminated).
  void Function(Map<String, String> data)? onTap;

  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('NotificationService: Firebase not configured, skipping ($e)');
      return;
    }
    _ready = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initLocalNotifications();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    try {
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) onToken?.call(_token!);
    } catch (e) {
      debugPrint('NotificationService: could not fetch token ($e)');
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _token = t;
      onToken?.call(t);
    });

    // Foreground: FCM does not show a system notification itself, so this app
    // shows one via flutter_local_notifications instead.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Tapped from background (app was alive, just not in front).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => onTap?.call(_stringData(m.data)),
    );

    // Tapped from terminated (app was launched by the notification tap).
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) onTap?.call(_stringData(initial.data));
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map) onTap?.call(_stringData(decoded));
      },
    );
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString();

    if (title == null && body == null) return;

    _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Map<String, String> _stringData(Map<dynamic, dynamic> data) =>
      data.map((k, v) => MapEntry(k.toString(), v.toString()));
}
