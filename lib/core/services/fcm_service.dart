import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';

import 'package:isdr/firebase_options.dart';

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  String? _fcmToken;
  StreamController<String>? _tokenController;
  StreamController<RemoteMessage>? _messageController;

  Stream<String> get tokenStream =>
      _tokenController?.stream ?? const Stream.empty();
  Stream<RemoteMessage> get messageStream =>
      _messageController?.stream ?? const Stream.empty();
  String? get fcmToken => _fcmToken;

  bool _initialized = false;
  Future<void>? _initFuture;

  /// Initialize Firebase and FCM (shared with background init in main.dart).
  Future<void> initialize() => ensureInitialized();

  /// Single init path so login does not race with `unawaited(initialize())` in main.
  Future<void> ensureInitialized() {
    if (_initialized) return Future.value();
    _initFuture ??= _performInitialize();
    return _initFuture!;
  }

  Future<void> _performInitialize() async {
    try {
      await _ensureFirebaseInitialized();
      _messaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();
      _tokenController = StreamController<String>.broadcast();
      _messageController = StreamController<RemoteMessage>.broadcast();

      _messaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _tokenController?.add(newToken);
        debugPrint('FCM Token refreshed: $newToken');
      });

      await _initializeLocalNotifications();
      await _requestPermissions();

      if (Platform.isIOS) {
        await _messaging!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        await _waitForAPNSToken();
      }

      await _fetchAndCacheToken();

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpened(initialMessage);
      }

      _initialized = true;
      debugPrint('FCM Service initialized successfully');
    } catch (e) {
      _initFuture = null;
      debugPrint('Error initializing FCM: $e');
      rethrow;
    }
  }

  /// Use at login: waits for the same init as main.dart, then returns a real token.
  Future<String?> getTokenForLogin({
    Duration maxWait = const Duration(seconds: 20),
  }) async {
    try {
      await ensureInitialized().timeout(maxWait);

      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        debugPrint('FCM token for login (cached): $_fcmToken');
        return _fcmToken;
      }

      if (Platform.isIOS) {
        await _waitForAPNSToken();
      }

      final token = await _fetchAndCacheToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM token for login (fetched): $token');
        return token;
      }

      // Token can arrive on onTokenRefresh moments after APNS on iOS.
      try {
        final fromStream = await tokenStream.first.timeout(
          const Duration(seconds: 8),
        );
        debugPrint('FCM token for login (stream): $fromStream');
        return fromStream;
      } catch (_) {
        debugPrint('FCM token for login: not available yet');
        return null;
      }
    } catch (e) {
      debugPrint('FCM getTokenForLogin error: $e');
      return _fcmToken;
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications',
      importance: Importance.high,
    );

    await _localNotifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _requestPermissions() async {
    try {
      final currentSettings = await _messaging!.getNotificationSettings();

      if (currentSettings.authorizationStatus !=
              AuthorizationStatus.authorized &&
          currentSettings.authorizationStatus !=
              AuthorizationStatus.provisional) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidSettings = await _messaging!.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          debugPrint(
            'Android notification permission: ${androidSettings.authorizationStatus}',
          );
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosSettings = await _messaging!.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          debugPrint(
            'iOS notification permission: ${iosSettings.authorizationStatus}',
          );
        }
      } else {
        debugPrint(
          'Notification permission already granted: ${currentSettings.authorizationStatus}',
        );
      }
    } catch (e) {
      debugPrint('Error checking/requesting notification permissions: $e');
    }
  }

  Future<void> _waitForAPNSToken() async {
    const maxAttempts = 40;
    const delay = Duration(milliseconds: 300);
    for (var i = 0; i < maxAttempts; i++) {
      final apnsToken = await _messaging!.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        debugPrint('APNS token available after ${i * 300}ms');
        return;
      }
      await Future<void>.delayed(delay);
    }
    debugPrint(
      'APNS token not set after ${maxAttempts * 300}ms; FCM token may fail.',
    );
  }

  Future<String?> _fetchAndCacheToken() async {
    try {
      final token = await _messaging!.getToken();
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
        _tokenController?.add(token);
        debugPrint('FCM Token: $token');
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');
    _messageController?.add(message);

    // iOS already shows the banner itself (setForegroundNotificationPresentationOptions
    // above), so only Android needs the local copy — otherwise iOS shows it twice.
    if (message.notification != null && !Platform.isIOS) {
      _showLocalNotification(message);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications!.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  void _handleMessageOpened(RemoteMessage message) {
    debugPrint('Message opened app: ${message.notification?.title}');
    _messageController?.add(message);
  }

  Future<String?> getToken() => getTokenForLogin();

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging?.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging?.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  void dispose() {
    _tokenController?.close();
    _messageController?.close();
    _tokenController = null;
    _messageController = null;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
  debugPrint('Background message received: ${message.notification?.title}');
}
