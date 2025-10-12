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

  // Add location for a user in a swap
  Future<void> addUserLocation({
    required String swapId,
    required String userId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final swapDoc = await _db.collection('swaps').doc(swapId).get();
      if (!swapDoc.exists) {
        throw Exception('Swap not found');
      }

      final swapData = swapDoc.data()!;
      final fromUserId = swapData['fromUserId'] as String;
      final toUserId = swapData['toUserId'] as String;

      // Determine which user this is (user01 or user02)
      final isUser01 = userId == fromUserId;
      final locationField = isUser01 ? 'user01Location' : 'user02Location';
      final confirmedField = isUser01
          ? 'user01LocationConfirmed'
          : 'user02LocationConfirmed';

      // Create location data
      final locationData = {
        'lat': latitude,
        'lng': longitude,
        'address': address,
      };

      // Update the swap with location data and confirmation status
      await _db.collection('swaps').doc(swapId).update({
        locationField: locationData,
        confirmedField: true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check if both users have confirmed their locations
      await _checkAndUpdateSwapStatus(swapId, fromUserId, toUserId);

      // Send notification to the other user
      final otherUserId = isUser01 ? toUserId : fromUserId;
      await _notificationService.createNotification(
        userId: otherUserId,
        title: 'Location Confirmed!',
        message:
            'Your swap partner has confirmed their location. Please add yours to complete the swap.',
        type: 'Swaps',
        tag: '#LocationConfirmed',
        data: {'swapId': swapId, 'action': 'add_location'},
      );
    } catch (e) {
      throw Exception('Failed to add user location: $e');
    }
  }

  // Check if both users have confirmed locations and update status
  Future<void> _checkAndUpdateSwapStatus(
    String swapId,
    String fromUserId,
    String toUserId,
  ) async {
    try {
      final swapDoc = await _db.collection('swaps').doc(swapId).get();
      if (!swapDoc.exists) return;

      final swapData = swapDoc.data()!;
      final user01LocationConfirmed =
          swapData['user01LocationConfirmed'] as bool? ?? false;
      final user02LocationConfirmed =
          swapData['user02LocationConfirmed'] as bool? ?? false;

      // Check if both users have confirmed their locations
      if (user01LocationConfirmed && user02LocationConfirmed) {
        // Both users have confirmed locations, update status
        await _db.collection('swaps').doc(swapId).update({
          'bothConfirmed': true,
          'deliveryStatus': 'InProgress',
          'status': 'ready_for_delivery',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Send notification to both users
        await _notificationService.createNotification(
          userId: fromUserId,
          title: '🚚 Delivery Ready!',
          message: 'Both locations confirmed! Your swap is ready for delivery.',
          type: 'Swaps',
          tag: '#ReadyForDelivery',
          data: {'swapId': swapId, 'action': 'view_swap'},
        );

        await _notificationService.createNotification(
          userId: toUserId,
          title: '🚚 Delivery Ready!',
          message: 'Both locations confirmed! Your swap is ready for delivery.',
          type: 'Swaps',
          tag: '#ReadyForDelivery',
          data: {'swapId': swapId, 'action': 'view_swap'},
        );

        // Create delivery records for both users
        await _createDeliveryRecords(swapId, fromUserId, toUserId);
      }
    } catch (e) {
      print('Error checking swap status: $e');
    }
  }

  // Create delivery records when both locations are confirmed
  Future<void> _createDeliveryRecords(
    String swapId,
    String fromUserId,
    String toUserId,
  ) async {
    try {
      // Get listing details
      final swapDoc = await _db.collection('swaps').doc(swapId).get();
      final swapData = swapDoc.data()!;

      final user01Location =
          swapData['user01Location'] as Map<String, dynamic>?;
      final user02Location =
          swapData['user02Location'] as Map<String, dynamic>?;

      if (user01Location == null || user02Location == null) {
        print('Error: Missing location data for swap $swapId');
        return;
      }

      final offeredListingDoc = await _db
          .collection('listings')
          .doc(swapData['listingOfferedId'])
          .get();
      final requestedListingDoc = await _db
          .collection('listings')
          .doc(swapData['listingRequestedId'])
          .get();

      if (offeredListingDoc.exists && requestedListingDoc.exists) {
        final offeredData = offeredListingDoc.data()!;
        final requestedData = requestedListingDoc.data()!;

        // Get user details
        final fromUserDoc = await _db.collection('users').doc(fromUserId).get();
        final toUserDoc = await _db.collection('users').doc(toUserId).get();

        // Get the main provider ID - use a dedicated delivery provider
        // For now, we'll use a default provider ID that all deliveries share
        // TODO: This should be configurable or retrieved from a settings collection
        final mainProviderId =
            'main_delivery_provider'; // Default provider ID for all deliveries
        final mainProviderName = 'SwapWear Delivery Service';

        // Create dual delivery records
        await _deliveryService.createDualDeliveries(
          swapId: swapId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          fromItemName: offeredData['title'] ?? 'Unknown Item',
          toItemName: requestedData['title'] ?? 'Unknown Item',
          providerId: mainProviderId,
          currentLocation: 'Location to be selected',
          estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
          fromItemImageUrl: offeredData['imageUrl'],
          toItemImageUrl: requestedData['imageUrl'],
          providerName: mainProviderName,
          fromUserName: fromUserDoc.data()?['name'] ?? 'Provider',
          toUserName: toUserDoc.data()?['name'] ?? 'Receiver',
          pickupLatitude: user01Location['lat']?.toDouble(),
          pickupLongitude: user01Location['lng']?.toDouble(),
          deliveryLatitude: user02Location['lat']?.toDouble(),
          deliveryLongitude: user02Location['lng']?.toDouble(),
          pickupAddress: user01Location['address'],
          deliveryAddress: user02Location['address'],
        );
      }
    } catch (e) {
      print('Error creating delivery records: $e');
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
        message:
            'Your swap has been confirmed. Please add your location to complete the setup.',
        type: 'Swaps',
        tag: '#Confirmed',
        data: {'swapId': swapId, 'action': 'add_location'},
      );

      await _notificationService.createNotification(
        userId: toUserId,
        title: 'Swap Confirmed!',
        message:
            'Your swap has been confirmed. Please add your location to complete the setup.',
        type: 'Swaps',
        tag: '#Confirmed',
        data: {'swapId': swapId, 'action': 'add_location'},
      );

      // Award achievements for both users
      await _awardSwapAchievements(fromUserId);
      await _awardSwapAchievements(toUserId);
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
