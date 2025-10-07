import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/swap_model.dart';
import 'delivery_service.dart';
import 'notifications_manager.dart';

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

      // Send notification to the recipient
      try {
        await NotificationsManager.instance.addTestNotification(
          userId: toUserId,
          type: 'Swaps',
          title: 'New Swap Request!',
          message: 'Someone wants to swap with you. Check your chats!',
          tag: '#SwapRequest',
        );
        print('✅ Swap request notification sent to user: $toUserId');
      } catch (e) {
        print('❌ Failed to send swap request notification: $e');
      }

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
      // Update swap status
      await _db.collection('swaps').doc(swapId).update({
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create delivery record
      final swap = await getSwapById(swapId);
      if (swap != null) {
        final deliveryService = DeliveryService();

        // Get listing details for item name
        final offeredListing = await _db
            .collection('listings')
            .doc(swap.listingOfferedId)
            .get();
        final requestedListing = await _db
            .collection('listings')
            .doc(swap.listingRequestedId)
            .get();

        final offeredTitle = offeredListing.data()?['title'] ?? 'Unknown Item';
        final requestedTitle =
            requestedListing.data()?['title'] ?? 'Unknown Item';

        // Get user details (for future use if needed)
        // final fromUser = await _db
        //     .collection('users')
        //     .doc(swap.fromUserId)
        //     .get();
        // final toUser = await _db.collection('users').doc(swap.toUserId).get();

        // Create delivery record
        await deliveryService.createDelivery(
          swapId: swapId,
          userId:
              swap.fromUserId, // The user who will set the delivery location
          itemName: '$offeredTitle → $requestedTitle',
          deliveryLocation: '', // User will set this later
          fromUserId: swap.fromUserId,
          toUserId: swap.toUserId,
        );

        // Send notifications to both users
        try {
          // Notify the person who made the request
          await NotificationsManager.instance.addTestNotification(
            userId: swap.fromUserId,
            type: 'Swaps',
            title: 'Swap Confirmed! 🎉',
            message:
                'Your swap request has been confirmed. Time to arrange delivery!',
            tag: '#SwapConfirmed',
          );

          // Notify the person who accepted
          await NotificationsManager.instance.addTestNotification(
            userId: swap.toUserId,
            type: 'Swaps',
            title: 'Swap Confirmed! 🎉',
            message: 'You confirmed the swap. Time to arrange delivery!',
            tag: '#SwapConfirmed',
          );

          print('✅ Swap confirmation notifications sent to both users');
        } catch (e) {
          print('❌ Failed to send swap confirmation notifications: $e');
        }
      }
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
