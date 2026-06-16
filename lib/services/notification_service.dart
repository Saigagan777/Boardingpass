import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Singleton service for Firebase Cloud Messaging push notifications.
///
/// Handles FCM initialisation, permission requests, token storage,
/// foreground notification display via `flutter_local_notifications`,
/// notification-tap routing, and token-refresh listeners.
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Callback invoked when the user taps a notification.
  ///
  /// Set this from your top-level widget to navigate to the appropriate screen.
  /// The [Map] contains the notification `data` payload.
  void Function(Map<String, dynamic>)? onNotificationTap;

  /// Whether [initialize] has already been called.
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Android notification channel
  // ---------------------------------------------------------------------------

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'boardingpass_high', // id
    'BoardingPause Notifications', // name
    description: 'High-priority notifications for BoardingPause',
    importance: Importance.high,
  );

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes the notification service.
  ///
  /// Should be called once during app startup (e.g., in `main()` after
  /// `Firebase.initializeApp()`).
  Future<void> initialize() async {
    if (_initialized) return;

    // --- Local notifications setup ---
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // --- FCM foreground handler ---
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // --- FCM notification tap (app in background / terminated) ---
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if the app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // --- Token refresh listener ---
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests notification permission from the user.
  ///
  /// Returns the [NotificationSettings] describing the granted permission
  /// level.
  Future<NotificationSettings> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return settings;
    } catch (e) {
      throw Exception('Failed to request notification permission: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // FCM token
  // ---------------------------------------------------------------------------

  /// Retrieves the current FCM token and stores it in the user's Firestore
  /// document.
  ///
  /// Returns the token string, or `null` on failure.
  Future<String?> getAndStoreFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _storeFcmToken(token);
      }
      return token;
    } catch (e) {
      throw Exception('Failed to get FCM token: $e');
    }
  }

  /// Writes [token] into the current user's Firestore document.
  Future<void> _storeFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      // Non-critical – token will be retried on next refresh.
    }
  }

  /// Called automatically when FCM issues a new token.
  void _onTokenRefresh(String token) {
    _storeFcmToken(token);
  }

  // ---------------------------------------------------------------------------
  // Foreground message handling
  // ---------------------------------------------------------------------------

  /// Displays an incoming FCM message as a local notification while the app
  /// is in the foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
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
      payload: jsonEncode(message.data),
    );
  }

  // ---------------------------------------------------------------------------
  // Notification tap handling
  // ---------------------------------------------------------------------------

  /// Handles notification taps originating from `onMessageOpenedApp` or the
  /// initial message.
  void _handleNotificationOpen(RemoteMessage message) {
    onNotificationTap?.call(message.data);
  }

  /// Handles taps on local notifications displayed in the foreground.
  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data =
            Map<String, dynamic>.from(jsonDecode(response.payload!));
        onNotificationTap?.call(data);
      } catch (_) {
        // Malformed payload – ignore.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Subscribes the device to a named FCM [topic].
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      throw Exception('Failed to subscribe to topic: $e');
    }
  }

  /// Unsubscribes the device from a named FCM [topic].
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      throw Exception('Failed to unsubscribe from topic: $e');
    }
  }
}
