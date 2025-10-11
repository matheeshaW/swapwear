import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');

  // Initialize Firebase if needed
  // await Firebase.initializeApp();

  // Note: In a real implementation, you'd call a public method here
  // For now, we'll just log the message
  print('Background message data: ${message.data}');
}

class FirebaseMessagingHandler {
  static final FirebaseMessagingHandler _instance =
      FirebaseMessagingHandler._internal();
  factory FirebaseMessagingHandler() => _instance;
  FirebaseMessagingHandler._internal();

  // Initialize background handler
  void initialize() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Handle notification tap and navigation
  void handleNotificationTap(RemoteMessage message, BuildContext context) {
    final data = message.data;

    if (data['action'] == 'open_chat' && data['chatId'] != null) {
      // Navigate to chat screen
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {'chatId': data['chatId'], 'senderId': data['senderId']},
      );
    } else if (data['action'] == 'view_swap' && data['swapId'] != null) {
      // Navigate to swap details
      Navigator.of(
        context,
      ).pushNamed('/swap-details', arguments: {'swapId': data['swapId']});
    } else {
      // Navigate to notifications screen
      Navigator.of(context).pushNamed('/notifications');
    }
  }

  // Setup message listeners
  void setupMessageListeners(BuildContext context) {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground message: ${message.messageId}');
      // The NotificationService will handle this automatically
    });

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background: ${message.messageId}');
      handleNotificationTap(message, context);
    });

    // Handle messages when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print('App opened from terminated state: ${message.messageId}');
        handleNotificationTap(message, context);
      }
    });
  }
}
