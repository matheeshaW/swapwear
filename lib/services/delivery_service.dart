import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery_model.dart';
import 'notification_service.dart';

class DeliveryService {
  DeliveryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> get _deliveries =>
      _db.collection('deliveries');

  // Create dual delivery records for a swap (one for each user)
  Future<List<String>> createDualDeliveries({
    required String swapId,
    required String fromUserId,
    required String toUserId,
    required String fromItemName,
    required String toItemName,
    String?
    providerId, // Made optional since we set it individually for each record
    required String currentLocation,
    DateTime? estimatedDelivery,
    String? fromItemImageUrl,
    String? toItemImageUrl,
    String? providerName,
    String? fromUserName,
    String? toUserName,
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? pickupAddress,
    String? deliveryAddress,
    double? distanceKm,
    double? co2SavedKg,
    String? routePolyline,
  }) async {
    try {
      final swapPairId = '${swapId}_pair';
      final batch = _db.batch();

      // Create delivery record for the sender (fromUserId)
      final fromDeliveryRef = _deliveries.doc('${swapId}_$fromUserId');
      final fromDelivery = DeliveryModel(
        swapId: swapId,
        itemName: fromItemName,
        providerId:
            providerId ??
            fromUserId, // Use passed providerId or fallback to fromUserId
        receiverId: toUserId,
        status: 'Pending',
        currentLocation: currentLocation,
        estimatedDelivery: estimatedDelivery,
        itemImageUrl: fromItemImageUrl,
        providerName: providerName,
        receiverName: toUserName,
        ownerId: fromUserId,
        partnerId: toUserId,
        swapPairId: swapPairId,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        pickupAddress: pickupAddress,
        deliveryAddress: deliveryAddress,
        distanceKm: distanceKm,
        co2SavedKg: co2SavedKg,
        routePolyline: routePolyline,
      );

      // Create delivery record for the receiver (toUserId)
      final toDeliveryRef = _deliveries.doc('${swapId}_$toUserId');
      final toDelivery = DeliveryModel(
        swapId: swapId,
        itemName: toItemName,
        providerId:
            providerId ??
            toUserId, // Use passed providerId or fallback to toUserId
        receiverId: fromUserId,
        status: 'Pending',
        currentLocation: currentLocation,
        estimatedDelivery: estimatedDelivery,
        itemImageUrl: toItemImageUrl,
        providerName: providerName,
        receiverName: fromUserName,
        ownerId: toUserId,
        partnerId: fromUserId,
        swapPairId: swapPairId,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        pickupAddress: pickupAddress,
        deliveryAddress: deliveryAddress,
        distanceKm: distanceKm,
        co2SavedKg: co2SavedKg,
        routePolyline: routePolyline,
      );

      batch.set(fromDeliveryRef, fromDelivery.toMap());
      batch.set(toDeliveryRef, toDelivery.toMap());

      await batch.commit();

      return [fromDeliveryRef.id, toDeliveryRef.id];
    } catch (e) {
      throw Exception('Failed to create dual deliveries: $e');
    }
  }

  // Create a new delivery record (legacy method for backward compatibility)
  Future<String> createDelivery({
    required String swapId,
    required String itemName,
    required String providerId,
    required String receiverId,
    required String currentLocation,
    DateTime? estimatedDelivery,
    String? itemImageUrl,
    String? providerName,
    String? receiverName,
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? pickupAddress,
    String? deliveryAddress,
    double? distanceKm,
    double? co2SavedKg,
    String? routePolyline,
  }) async {
    try {
      final delivery = DeliveryModel(
        swapId: swapId,
        itemName: itemName,
        providerId: providerId,
        receiverId: receiverId,
        status: 'Pending',
        currentLocation: currentLocation,
        estimatedDelivery: estimatedDelivery,
        itemImageUrl: itemImageUrl,
        providerName: providerName,
        receiverName: receiverName,
        ownerId:
            receiverId, // For legacy compatibility, use receiverId as owner
        partnerId:
            providerId, // For legacy compatibility, use providerId as partner
        swapPairId: '${swapId}_legacy', // Legacy identifier
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        pickupAddress: pickupAddress,
        deliveryAddress: deliveryAddress,
        distanceKm: distanceKm,
        co2SavedKg: co2SavedKg,
        routePolyline: routePolyline,
      );

      final docRef = await _deliveries.add(delivery.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  // Get delivery by ID
  Future<DeliveryModel?> getDelivery(String deliveryId) async {
    try {
      final doc = await _deliveries.doc(deliveryId).get();
      if (doc.exists) {
        return DeliveryModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get delivery: $e');
    }
  }

  // Get delivery by swap ID
  Future<DeliveryModel?> getDeliveryBySwapId(String swapId) async {
    try {
      final query = await _deliveries
          .where('swapId', isEqualTo: swapId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return DeliveryModel.fromMap(
          query.docs.first.data(),
          query.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get delivery by swap ID: $e');
    }
  }

  // Get delivery by swap ID and owner ID (for dual delivery system)
  Future<DeliveryModel?> getDeliveryBySwapAndOwner(
    String swapId,
    String ownerId,
  ) async {
    try {
      final doc = await _deliveries.doc('${swapId}_$ownerId').get();
      if (doc.exists) {
        return DeliveryModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get delivery by swap and owner: $e');
    }
  }

  // Get all deliveries for a specific owner
  Future<List<DeliveryModel>> getDeliveriesByOwner(String ownerId) async {
    try {
      final query = await _deliveries
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('lastUpdated', descending: true)
          .get();

      return query.docs
          .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get deliveries by owner: $e');
    }
  }

  // Get all deliveries for a swap pair (both users)
  Future<List<DeliveryModel>> getDeliveriesBySwapPair(String swapPairId) async {
    try {
      final query = await _deliveries
          .where('swapPairId', isEqualTo: swapPairId)
          .orderBy('lastUpdated', descending: true)
          .get();

      return query.docs
          .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get deliveries by swap pair: $e');
    }
  }

  // Stream delivery by ID
  Stream<DeliveryModel?> streamDelivery(String deliveryId) {
    return _deliveries.doc(deliveryId).snapshots().map((doc) {
      if (doc.exists) {
        return DeliveryModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Stream delivery by swap ID
  Stream<DeliveryModel?> streamDeliveryBySwapId(String swapId) {
    print('DeliveryService - Streaming delivery by swap ID: $swapId');
    return _deliveries.where('swapId', isEqualTo: swapId).limit(1).snapshots().map((
      snapshot,
    ) {
      print(
        'DeliveryService - Found ${snapshot.docs.length} deliveries for swapId: $swapId',
      );
      if (snapshot.docs.isNotEmpty) {
        final delivery = DeliveryModel.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
        print(
          'DeliveryService - Found delivery: ${delivery.itemName} (${delivery.status})',
        );
        return delivery;
      }
      print('DeliveryService - No deliveries found for swapId: $swapId');
      return null;
    });
  }

  // Stream delivery by swap ID and owner ID (for dual delivery system)
  Stream<DeliveryModel?> streamDeliveryBySwapAndOwner(
    String swapId,
    String ownerId,
  ) {
    final docId = '${swapId}_$ownerId';
    print('DeliveryService - Streaming delivery by swap and owner: $docId');
    return _deliveries.doc(docId).snapshots().map((doc) {
      print(
        'DeliveryService - Document exists: ${doc.exists} for docId: $docId',
      );
      if (doc.exists) {
        final delivery = DeliveryModel.fromMap(doc.data()!, doc.id);
        print(
          'DeliveryService - Found delivery: ${delivery.itemName} (${delivery.status})',
        );
        return delivery;
      }
      print('DeliveryService - No delivery found for docId: $docId');
      return null;
    });
  }

  // Update delivery location
  Future<void> updateDeliveryLocation({
    required String swapId,
    required String deliveryAddress,
  }) async {
    try {
      final query = await _deliveries
          .where('swapId', isEqualTo: swapId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await _deliveries.doc(query.docs.first.id).update({
          'deliveryAddress': deliveryAddress,
          'currentLocation': deliveryAddress,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to update delivery location: $e');
    }
  }

  // Stream deliveries for provider
  Stream<List<DeliveryModel>> streamProviderDeliveries(String providerId) {
    print('DeliveryService - Querying deliveries for provider: $providerId');
    return _deliveries
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
          print(
            'DeliveryService - Found ${snapshot.docs.length} deliveries for provider: $providerId',
          );
          final deliveries = snapshot.docs
              .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
              .toList();

          // Sort by lastUpdated descending locally
          deliveries.sort((a, b) {
            final aTime = a.lastUpdated ?? DateTime(1970);
            final bTime = b.lastUpdated ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });

          return deliveries;
        })
        .handleError((error) {
          print(
            'DeliveryService - Error streaming provider deliveries: $error',
          );
          return <DeliveryModel>[];
        });
  }

  // Stream deliveries for user (either as provider or owner)
  Stream<List<DeliveryModel>> streamUserDeliveries(String userId) {
    return _deliveries
        .where('providerId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Stream all deliveries for provider management
  Stream<List<DeliveryModel>> streamAllDeliveries() {
    return _deliveries
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Stream deliveries for receiver
  Stream<List<DeliveryModel>> streamReceiverDeliveries(String receiverId) {
    return _deliveries
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Update delivery status
  Future<void> updateDeliveryStatus({
    required String deliveryId,
    required String newStatus,
    String? currentLocation,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (currentLocation != null) {
        updateData['currentLocation'] = currentLocation;
      }

      // Update only the specific delivery
      await _deliveries.doc(deliveryId).update(updateData);
      print(
        'DeliveryService - Updated delivery: $deliveryId to status: $newStatus',
      );

      // Get delivery data for notifications
      final deliveryDoc = await _deliveries.doc(deliveryId).get();
      if (deliveryDoc.exists) {
        final deliveryData = deliveryDoc.data()!;
        final itemName = deliveryData['itemName'] as String?;
        final swapId = deliveryData['swapId'] as String?;
        final ownerId = deliveryData['ownerId'] as String?;

        String title;
        String message;
        String tag;

        switch (newStatus) {
          case 'Approved':
            title = 'Delivery Approved';
            message =
                'Your delivery for "$itemName" has been approved and is being prepared.';
            tag = '#Approved';
            break;
          case 'Picked Up':
            title = 'Item Picked Up';
            message =
                'Your item "$itemName" has been picked up and is on its way!';
            tag = '#PickedUp';
            break;
          case 'In Transit':
            title = 'Out for Delivery';
            message = 'Your item "$itemName" is now out for delivery!';
            tag = '#InTransit';
            break;
          case 'Delivered':
            title = 'Delivery Completed';
            message =
                'Your delivery for "$itemName" has been completed successfully!';
            tag = '#Delivered';
            break;
          default:
            title = 'Delivery Update';
            message = 'Your delivery status has been updated to $newStatus.';
            tag = '#Updated';
        }

        // Send notification to the owner of this specific delivery
        if (ownerId != null) {
          await _notificationService.createNotification(
            userId: ownerId,
            title: title,
            message: message,
            type: 'Deliveries',
            tag: tag,
            data: {
              'swapId': swapId,
              'deliveryId': deliveryId,
              'status': newStatus,
              'action': 'track_delivery',
            },
          );
          print('DeliveryService - Sent notification to owner: $ownerId');
        }
      }
    } catch (e) {
      throw Exception('Failed to update delivery status: $e');
    }
  }

  // Update delivery
  Future<void> updateDelivery({
    required String deliveryId,
    String? status,
    String? currentLocation,
    DateTime? estimatedDelivery,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (status != null) updateData['status'] = status;
      if (currentLocation != null)
        updateData['currentLocation'] = currentLocation;
      if (estimatedDelivery != null) {
        updateData['estimatedDelivery'] = Timestamp.fromDate(estimatedDelivery);
      }

      await _deliveries.doc(deliveryId).update(updateData);

      // Send notification for delivery status update
      if (status != null) {
        final deliveryDoc = await _deliveries.doc(deliveryId).get();
        if (deliveryDoc.exists) {
          // Delivery updated successfully
        }
      }
    } catch (e) {
      throw Exception('Failed to update delivery: $e');
    }
  }

  // Delete delivery
  Future<void> deleteDelivery(String deliveryId) async {
    try {
      await _deliveries.doc(deliveryId).delete();
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  // Complete delivery and mark swap as completed
  Future<void> completeDelivery(String deliveryId) async {
    try {
      // Update delivery status to completed
      await _deliveries.doc(deliveryId).update({
        'status': 'Delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Get delivery details
      final deliveryDoc = await _deliveries.doc(deliveryId).get();
      if (deliveryDoc.exists) {
        final deliveryData = deliveryDoc.data()!;
        final swapId = deliveryData['swapId'] as String?;

        if (swapId != null) {
          // Mark swap as completed
          await FirebaseFirestore.instance
              .collection('swaps')
              .doc(swapId)
              .update({
                'status': 'completed',
                'completedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

          // Create delivery completion notifications
          final fromUserId = deliveryData['providerId'] as String?;
          final toUserId = deliveryData['receiverId'] as String?;
          final itemName = deliveryData['itemName'] as String?;

          if (fromUserId != null && toUserId != null) {
            // Get swapId for navigation
            final swapId = deliveryData['swapId'] as String?;

            // Notify provider
            await _notificationService.createNotification(
              userId: fromUserId,
              title: '🚚 Delivery Completed!',
              message:
                  'Your delivery of "$itemName" has been completed successfully.',
              type: 'Deliveries',
              tag: '#Completed',
              data: {
                'deliveryId': deliveryId,
                'swapId': swapId,
                'action': 'view_delivery',
              },
            );

            // Notify receiver
            await _notificationService.createNotification(
              userId: toUserId,
              title: '📦 Item Delivered!',
              message: 'Your "$itemName" has been delivered successfully.',
              type: 'Deliveries',
              tag: '#Delivered',
              data: {
                'deliveryId': deliveryId,
                'swapId': swapId,
                'action': 'view_delivery',
              },
            );
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to complete delivery: $e');
    }
  }

  // Get delivery statistics for provider
  Future<Map<String, int>> getProviderStats(String providerId) async {
    try {
      final snapshot = await _deliveries
          .where('providerId', isEqualTo: providerId)
          .get();

      int active = 0;
      int completed = 0;

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'Pending';
        if (status == 'Completed') {
          completed++;
        } else {
          active++;
        }
      }

      return {'active': active, 'completed': completed};
    } catch (e) {
      throw Exception('Failed to get provider stats: $e');
    }
  }
}
