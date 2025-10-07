import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/swap_model.dart';

class SwapService {
  final FirebaseFirestore _db;
  SwapService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<String> createSwapRequest({
    required String fromUserId,
    required String toUserId,
    required String listingOfferedId,
    required String listingRequestedId,
  }) async {
    try {
      final batch = _db.batch();
      final swapRef = _db.collection('swaps').doc();
      final chatRef = _db.collection('chats').doc(swapRef.id);
      final now = FieldValue.serverTimestamp();

      batch.set(swapRef, {
        'listingOfferedId': listingOfferedId,
        'listingRequestedId': listingRequestedId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
        'chatId': swapRef.id,
      });
      batch.set(chatRef, {
        'participants': [fromUserId, toUserId],
      });
      await batch.commit();
      return swapRef.id;
    } catch (e) {
      throw Exception('Failed to create swap request: $e');
    }
  }

  Future<void> updateSwapStatus(String swapId, String status) async {
    try {
      await _db.collection('swaps').doc(swapId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update swap status: $e');
    }
  }

  Future<void> confirmSwap(String swapId) async {
    try {
      await _db.collection('swaps').doc(swapId).update({
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to confirm swap: $e');
    }
  }

  Stream<List<SwapModel>> getUserSwaps(String userId) {
    try {
      final fromStream = _db
          .collection('swaps')
          .where('fromUserId', isEqualTo: userId)
          .snapshots();
      final toStream = _db
          .collection('swaps')
          .where('toUserId', isEqualTo: userId)
          .snapshots();
      return fromStream.asyncMap((fromSnap) async {
        final fromList = fromSnap.docs
            .map((doc) => SwapModel.fromMap(doc.data(), doc.id))
            .toList();
        final toSnap = await toStream.first;
        final toList = toSnap.docs
            .map((doc) => SwapModel.fromMap(doc.data(), doc.id))
            .toList();
        // Avoid duplicates if user is both from and to
        final all = <String, SwapModel>{};
        for (final s in fromList) {
          all[s.id ?? ''] = s;
        }
        for (final s in toList) {
          all[s.id ?? ''] = s;
        }
        return all.values.toList();
      });
    } catch (e) {
      // Return empty stream on error
      return const Stream<List<SwapModel>>.empty();
    }
  }

  Future<SwapModel?> getSwapById(String swapId) async {
    try {
      final doc = await _db.collection('swaps').doc(swapId).get();
      if (!doc.exists) return null;
      return SwapModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get swap: $e');
    }
  }
}
