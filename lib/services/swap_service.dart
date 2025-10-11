import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/swap_model.dart';
import 'delivery_service.dart';
import 'notification_service.dart';
import 'achievements_service.dart';

class SwapService {
  final FirebaseFirestore _db;
  final DeliveryService _deliveryService;
  final NotificationService _notificationService = NotificationService();
  final AchievementsService _achievementsService = AchievementsService();

  SwapService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _deliveryService = DeliveryService(firestore: firestore);

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

      // Create notification for the recipient
      await _notificationService.createNotification(
        userId: toUserId,
        title: 'New Swap Request!',
        message: 'Someone wants to swap with you. Check your swaps to respond.',
        type: 'Swaps',
        tag: '#NewRequest',
        data: {'swapId': swapRef.id, 'action': 'view_swap'},
      );

      return swapRef.id;
    } catch (e) {
      throw Exception('Failed to create swap request: $e');
    }
  }

  Future<void> updateSwapStatus(String swapId, String status) async {
    try {
      // Get swap details first
      final swapDoc = await _db.collection('swaps').doc(swapId).get();
      if (!swapDoc.exists) {
        throw Exception('Swap not found');
      }

      final swapData = swapDoc.data()!;
      final fromUserId = swapData['fromUserId'] as String;
      final toUserId = swapData['toUserId'] as String;

      await _db.collection('swaps').doc(swapId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notifications based on status
      String title;
      String message;
      String tag;

      switch (status) {
        case 'accepted':
          title = 'Swap Accepted!';
          message = 'Your swap request has been accepted!';
          tag = '#Accepted';
          break;
        case 'rejected':
          title = 'Swap Declined';
          message = 'Your swap request was declined.';
          tag = '#Declined';
          break;
        case 'cancelled':
          title = 'Swap Cancelled';
          message = 'The swap has been cancelled.';
          tag = '#Cancelled';
          break;
        default:
          title = 'Swap Updated';
          message = 'Your swap status has been updated.';
          tag = '#Updated';
      }

      // Notify the requester
      await _notificationService.createNotification(
        userId: fromUserId,
        title: title,
        message: message,
        type: 'Swaps',
        tag: tag,
        data: {'swapId': swapId, 'action': 'view_swap'},
      );

      // If accepted, also notify the recipient and award achievements
      if (status == 'accepted') {
        await _notificationService.createNotification(
          userId: toUserId,
          title: 'Swap Confirmed!',
          message: 'You have successfully confirmed the swap.',
          type: 'Swaps',
          tag: '#Confirmed',
          data: {'swapId': swapId, 'action': 'view_swap'},
        );

        // Removed to prevent multiple awards
        // await _awardSwapAchievements(fromUserId);
        // await _awardSwapAchievements(toUserId);
      }
    } catch (e) {
      throw Exception('Failed to update swap status: $e');
    }
  }

  Future<void> confirmSwap(String swapId) async {
    try {
      // Get swap details first
      final swapDoc = await _db.collection('swaps').doc(swapId).get();
      if (!swapDoc.exists) {
        throw Exception('Swap not found');
      }

      final swapData = swapDoc.data()!;
      final fromUserId = swapData['fromUserId'] as String;
      final toUserId = swapData['toUserId'] as String;

      // Update swap status
      await _db.collection('swaps').doc(swapId).update({
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notifications for both users
      await _notificationService.createNotification(
        userId: fromUserId,
        title: 'Swap Confirmed!',
        message: 'Your swap has been confirmed and delivery is being arranged.',
        type: 'Swaps',
        tag: '#Confirmed',
        data: {'swapId': swapId, 'action': 'view_swap'},
      );

      await _notificationService.createNotification(
        userId: toUserId,
        title: 'Swap Confirmed!',
        message: 'Your swap has been confirmed and delivery is being arranged.',
        type: 'Swaps',
        tag: '#Confirmed',
        data: {'swapId': swapId, 'action': 'view_swap'},
      );

      // Get listing details for the offered item
      final offeredListingDoc = await _db
          .collection('listings')
          .doc(swapData['listingOfferedId'])
          .get();

      if (offeredListingDoc.exists) {
        final offeredData = offeredListingDoc.data()!;

        // Get user details for provider and receiver
        final providerDoc = await _db
            .collection('users')
            .doc(swapData['fromUserId'])
            .get();
        final receiverDoc = await _db
            .collection('users')
            .doc(swapData['toUserId'])
            .get();

        // Get listing details for the requested item
        final requestedListingDoc = await _db
            .collection('listings')
            .doc(swapData['listingRequestedId'])
            .get();

        // Create dual delivery records (one for each user)
        await _deliveryService.createDualDeliveries(
          swapId: swapId,
          fromUserId: swapData['fromUserId'],
          toUserId: swapData['toUserId'],
          fromItemName: offeredData['title'] ?? 'Unknown Item',
          toItemName: requestedListingDoc.data()?['title'] ?? 'Unknown Item',
          providerId:
              swapData['fromUserId'], // Assuming fromUserId is the provider
          currentLocation: 'Location to be selected',
          estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
          fromItemImageUrl: offeredData['imageUrl'],
          toItemImageUrl: requestedListingDoc.data()?['imageUrl'],
          providerName: providerDoc.data()?['name'] ?? 'Provider',
          fromUserName: providerDoc.data()?['name'] ?? 'Provider',
          toUserName: receiverDoc.data()?['name'] ?? 'Receiver',
        );

        // Create delivery notifications for each user's specific item
        await _notificationService.createNotification(
          userId: fromUserId,
          title: 'Delivery Started',
          message:
              'Your "${offeredData['title'] ?? 'item'}" is now being prepared for delivery.',
          type: 'Deliveries',
          tag: '#InTransit',
          data: {'swapId': swapId, 'action': 'track_delivery'},
        );

        await _notificationService.createNotification(
          userId: toUserId,
          title: 'Delivery Started',
          message:
              'Your "${requestedListingDoc.data()?['title'] ?? 'item'}" is now being prepared for delivery.',
          type: 'Deliveries',
          tag: '#InTransit',
          data: {'swapId': swapId, 'action': 'track_delivery'},
        );

        // Award achievements for both users
        await _awardSwapAchievements(fromUserId);
        await _awardSwapAchievements(toUserId);
      }
    } catch (e) {
      throw Exception('Failed to confirm swap: $e');
    }
  }

  // Award achievements for swap completion
  Future<void> _awardSwapAchievements(String userId) async {
    try {
      final newBadges = await _achievementsService.awardSwapCompletion(userId);

      // Send notification for new badges
      if (newBadges.isNotEmpty) {
        for (final badgeId in newBadges) {
          final badge = AchievementsService.badgeDefinitions[badgeId];
          if (badge != null) {
            await _notificationService.createNotification(
              userId: userId,
              title: '🏆 New Badge Earned!',
              message: 'You earned the ${badge['name']} badge!',
              type: 'Badges',
              tag: '#NewBadge',
              data: {'badgeId': badgeId, 'action': 'view_achievements'},
            );
          }
        }
      }
    } catch (e) {
      print('Error awarding swap achievements: $e');
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
