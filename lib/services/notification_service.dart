import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Request permission for notifications
    await _requestPermission();

    // Get FCM token and save to Firestore
    await _saveFCMToken();

    // Listen for FCM messages
    _setupFCMListeners();

    _isInitialized = true;
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Request notification permission
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Setup FCM message listeners
  void _setupFCMListeners() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle messages when app is opened from terminated state
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleBackgroundMessage(message);
      }
    });
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');

    // Save notification to Firestore
    await _saveNotificationToFirestore(message);

    // Show local notification
    await _showLocalNotification(message);
  }

  // Handle background messages
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Received background message: ${message.messageId}');

    // Save notification to Firestore
    await _saveNotificationToFirestore(message);

    // Navigate to specific screen based on data
    if (message.data['action'] == 'open_chat' &&
        message.data['chatId'] != null) {
      // This will be handled by the main app navigation
      print('Should navigate to chat: ${message.data['chatId']}');
    }
  }

  // Save notification to Firestore
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notification = NotificationModel(
        title: message.notification?.title ?? 'New Notification',
        message: message.notification?.body ?? '',
        type: message.data['type'] ?? 'Swaps',
        tag: message.data['tag'],
        timestamp: DateTime.now(),
        isRead: false,
        imageUrl:
            message.notification?.android?.imageUrl ??
            message.notification?.apple?.imageUrl,
        data: message.data.isNotEmpty ? message.data : null,
      );

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add(notification.toMap());
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'swapwear_notifications',
      'SwapWear Notifications',
      channelDescription: 'Notifications for SwapWear app',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Navigate to notifications screen or specific screen
  }

  // Stream notifications for a user
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();

          // Sort by timestamp in descending order (newest first)
          notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return notifications;
        });
  }

  // Stream notifications by type
  Stream<List<NotificationModel>> streamNotificationsByType(
    String userId,
    String type,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();

          // Sort by timestamp in descending order (newest first)
          notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return notifications;
        });
  }

  // Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _db.batch();
      final notifications = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications(String userId) async {
    try {
      final batch = _db.batch();
      final notifications = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }

  // Get unread count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Stream unread count
  Stream<int> streamUnreadCount(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Send test notification (for development)
  Future<void> sendTestNotification(String userId) async {
    try {
      final notification = NotificationModel(
        title: 'Test Notification',
        message: 'This is a test notification from SwapWear!',
        type: 'Swaps',
        tag: '#Test',
        timestamp: DateTime.now(),
        isRead: false,
      );

      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notification.toMap());
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  // Create a notification directly in Firestore
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? tag,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Check if user document exists, create if not
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        await _db.collection('users').doc(userId).set({
          'createdAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        });
      }

      final notification = NotificationModel(
        title: title,
        message: message,
        type: type,
        tag: tag,
        timestamp: DateTime.now(),
        isRead: false,
        imageUrl: imageUrl,
        data: data,
      );

      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notification.toMap());
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Create sample notifications for testing
  Future<void> createSampleNotifications(String userId) async {
    try {
      final notifications = [
        NotificationModel(
          title: 'Swap Approved!',
          message: 'Your request with @alex was accepted.',
          type: 'Swaps',
          tag: '#EcoHero',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isRead: false,
        ),
        NotificationModel(
          title: 'Delivery Completed',
          message: 'Your item has been successfully delivered.',
          type: 'Deliveries',
          tag: '#VintageStyle',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
        ),
        NotificationModel(
          title: 'New Badge Earned!',
          message: 'You\'ve earned the Eco Warrior badge!',
          type: 'Badges',
          tag: '#EcoHero',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
        ),
        NotificationModel(
          title: 'New Message',
          message: 'You have a new message from @sarah_eco.',
          type: 'Swaps',
          tag: '#EcoHero',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
        ),
      ];

      final batch = _db.batch();
      for (final notification in notifications) {
        final docRef = _db
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();
        batch.set(docRef, notification.toMap());
      }

      await batch.commit();
    } catch (e) {
      print('Error creating sample notifications: $e');
    }
  }

  // Send FCM notification to a specific user
  Future<void> sendFCMNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get target user's FCM token
      final userDoc = await _db.collection('users').doc(targetUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        print('No FCM token found for user: $targetUserId');
        return;
      }

      // This would typically be done via a Cloud Function
      // For now, we'll create a local notification and save to Firestore
      await createNotification(
        userId: targetUserId,
        title: title,
        message: body,
        type: type,
        tag: '#$type',
        data: data,
      );

      // Show local notification if app is in foreground
      await _showChatLocalNotification(
        title: title,
        body: body,
        data: data ?? {},
      );
    } catch (e) {
      print('Error sending FCM notification: $e');
    }
  }

  // Show local notification for chat messages
  Future<void> _showChatLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'chat_notifications',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: const RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.wav',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data.toString(),
    );
  }

  // Get FCM token for current user
  Future<String?> getCurrentUserFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Update FCM token for current user
  Future<void> updateFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token updated for user: ${user.uid}');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Check if notifications are enabled for user
  Future<bool> areNotificationsEnabled(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return true; // Default to enabled

      final userData = userDoc.data()!;
      return userData['notificationsEnabled'] as bool? ?? true;
    } catch (e) {
      print('Error checking notification settings: $e');
      return true; // Default to enabled
    }
  }

  // Toggle notifications for user
  Future<void> toggleNotifications(String userId, bool enabled) async {
    try {
      await _db.collection('users').doc(userId).update({
        'notificationsEnabled': enabled,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling notifications: $e');
    }
  }
}
