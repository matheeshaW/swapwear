import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _db;
  ChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    try {
      final msgRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();
      await msgRef.set({
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
      });
    } catch (e) {
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
      // Return empty stream on error
      return const Stream<List<MessageModel>>.empty();
    }
  }

  Future<void> markUnreadAsSeen(String chatId, String currentUserId) async {
    try {
      final query = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('seen', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUserId)
          .get();
      if (query.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'seen': true});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark messages as seen: $e');
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
}
