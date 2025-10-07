import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsManager {
  NotificationsManager._();
  static final NotificationsManager instance = NotificationsManager._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Ensure Firebase is initialized
    try {
      Firebase.app();
    } catch (_) {
      await Firebase.initializeApp();
    }

    // Request permissions
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Init local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(initSettings);

    // Save token
    await _saveToken();
    _fcm.onTokenRefresh.listen((t) => _saveToken(token: t));

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_onMessage);
    // Taps
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);

    // Background handler must be top-level in real apps; here we rely on default setup
  }

  Future<void> _saveToken({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fcmToken = token ?? await _fcm.getToken();
    if (fcmToken == null) return;
    await _db.collection('users').doc(user.uid).set({
      'token': fcmToken,
    }, SetOptions(merge: true));
  }

  void _onMessage(RemoteMessage message) async {
    // Show local notification while foreground
    final notif = message.notification;
    if (notif != null) {
      await _local.show(
        notif.hashCode,
        notif.title,
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'swapwear_channel',
            'SwapWear',
            channelDescription: 'In-app notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
    // Persist to Firestore
    await saveToUserInbox(message);
  }

  void _onMessageTap(RemoteMessage message) {
    // Optional: handle navigation based on message.data
  }

  Future<void> saveToUserInbox(RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = message.data;
    final doc = {
      'title': message.notification?.title ?? data['title'] ?? '',
      'message': message.notification?.body ?? data['message'] ?? '',
      'type': data['type'] ?? 'Swaps',
      'tag': data['tag'],
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add(doc);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamByType({
    required String userId,
    required String type,
  }) {
    print('Streaming notifications for user: $userId, type: $type');
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: type)
        .snapshots();
  }

  // Test method to get all notifications
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllNotifications({
    required String userId,
  }) {
    print('Streaming ALL notifications for user: $userId');
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .snapshots();
  }

  // Stream for unread notifications count (for bell badge)
  Stream<int> unreadNotificationsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead({required String userId, required String id}) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(id)
        .update({'isRead': true});
  }

  // Test function to add sample notifications
  Future<void> addTestNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? tag,
  }) async {
    try {
      print('Adding test notification: $title for user: $userId');
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': title,
            'message': message,
            'type': type,
            'tag': tag,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
      print('Test notification added successfully');
    } catch (e) {
      print('Error adding test notification: $e');
    }
  }
}
