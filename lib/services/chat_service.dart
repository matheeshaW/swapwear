import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _db;
  final NotificationService _notificationService = NotificationService();

  ChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Send a message with isRead set to false initially
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String text, {
    String? receiverId,
  }) async {
    try {
      final msgRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      await msgRef.set({
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false, // Changed from 'seen' to 'isRead'
      });

      // Send notification to other participants
      await _sendChatNotification(chatId, senderId, text);
    } catch (e) {
      debugPrint('Failed to send message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    try {
      return _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (e) {
      debugPrint('Error getting messages stream: $e');
      return const Stream<List<MessageModel>>.empty();
    }
  }

  /// Mark messages as read for the current user (WhatsApp-style)
  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    try {
      // Query unread messages where current user is the receiver
      final query = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      debugPrint('Marked ${query.docs.length} messages as read');
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }

  /// Legacy method for backward compatibility
  Future<void> markUnreadAsSeen(String chatId, String currentUserId) async {
    try {
      // First try the new method with receiverId
      await markMessagesAsRead(chatId, currentUserId);

      // Fallback: Also handle old 'seen' field for backward compatibility
      final oldQuery = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('seen', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUserId)
          .get();

      if (oldQuery.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in oldQuery.docs) {
          batch.update(doc.reference, {'seen': true, 'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Failed to mark messages as seen: $e');
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Get unread message count for a specific chat
  Future<int> getUnreadMessageCount(String chatId, String userId) async {
    try {
      final unreadMessages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Send chat notification to other participants
  Future<void> _sendChatNotification(
    String chatId,
    String senderId,
    String text,
  ) async {
    try {
      // Get chat participants
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants'] ?? []);

      // Get sender name for notification
      final senderDoc = await _db.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['name'] ?? 'Someone';

      // Send FCM notification to all participants except sender
      for (final participantId in participants) {
        if (participantId != senderId) {
          // Check if notifications are enabled for this user
          final notificationsEnabled = await _notificationService
              .areNotificationsEnabled(participantId);

          if (notificationsEnabled) {
            await _notificationService.sendFCMNotification(
              targetUserId: participantId,
              title: '💬 New Message from $senderName',
              body: text.length > 50 ? '${text.substring(0, 50)}...' : text,
              type: 'Chat',
              data: {
                'chatId': chatId,
                'senderId': senderId,
                'action': 'open_chat',
              },
            );
          }
        }
      }
    } catch (e) {
      // Don't throw error for notification failure
      debugPrint('Failed to send chat notification: $e');
    }
  }
}
