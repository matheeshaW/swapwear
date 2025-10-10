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

  // Create a new delivery record
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
    return _deliveries
        .where('swapId', isEqualTo: swapId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return DeliveryModel.fromMap(
              snapshot.docs.first.data(),
              snapshot.docs.first.id,
            );
          }
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
    return _deliveries
        .where('providerId', isEqualTo: providerId)
        .orderBy('lastUpdated', descending: true)
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

      await _deliveries.doc(deliveryId).update(updateData);

      // Send notification for delivery status update
      final deliveryDoc = await _deliveries.doc(deliveryId).get();
      if (deliveryDoc.exists) {
        final deliveryData = deliveryDoc.data()!;
        final providerId = deliveryData['providerId'] as String?;
        final receiverId = deliveryData['receiverId'] as String?;
        final itemName = deliveryData['itemName'] as String?;

        String title;
        String message;
        String tag;

        switch (newStatus) {
          case 'Approved':
            title = 'Delivery Approved';
            message =
                'Your delivery for $itemName has been approved and is being prepared.';
            tag = '#Approved';
            break;
          case 'Out for Delivery':
            title = 'Out for Delivery';
            message = 'Your item $itemName is now out for delivery!';
            tag = '#OutForDelivery';
            break;
          case 'Completed':
            title = 'Delivery Completed';
            message =
                'Your delivery for $itemName has been completed successfully!';
            tag = '#Completed';
            break;
          default:
            title = 'Delivery Update';
            message = 'Your delivery status has been updated to $newStatus.';
            tag = '#Updated';
        }

        // Notify both provider and receiver
        if (providerId != null) {
          await _notificationService.createNotification(
            userId: providerId,
            title: title,
            message: message,
            type: 'Deliveries',
            tag: tag,
            data: {'deliveryId': deliveryId, 'action': 'track_delivery'},
          );
        }

        if (receiverId != null) {
          await _notificationService.createNotification(
            userId: receiverId,
            title: title,
            message: message,
            type: 'Deliveries',
            tag: tag,
            data: {'deliveryId': deliveryId, 'action': 'track_delivery'},
          );
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
          final deliveryData = deliveryDoc.data()!;
          final providerId = deliveryData['providerId'] as String?;
          final receiverId = deliveryData['receiverId'] as String?;
          final itemName = deliveryData['itemName'] as String?;

          String title;
          String message;
          String tag;

          switch (status) {
            case 'Approved':
              title = 'Delivery Approved';
              message =
                  'Your delivery for $itemName has been approved and is being prepared.';
              tag = '#Approved';
              break;
            case 'Out for Delivery':
              title = 'Out for Delivery';
              message = 'Your item $itemName is now out for delivery!';
              tag = '#OutForDelivery';
              break;
            case 'Completed':
              title = 'Delivery Completed';
              message =
                  'Your delivery for $itemName has been completed successfully!';
              tag = '#Completed';
              break;
            default:
              title = 'Delivery Update';
              message = 'Your delivery status has been updated to $status.';
              tag = '#Updated';
          }

          // Notify both provider and receiver
          if (providerId != null) {
            await _notificationService.createNotification(
              userId: providerId,
              title: title,
              message: message,
              type: 'Deliveries',
              tag: tag,
              data: {'deliveryId': deliveryId, 'action': 'track_delivery'},
            );
          }

          if (receiverId != null) {
            await _notificationService.createNotification(
              userId: receiverId,
              title: title,
              message: message,
              type: 'Deliveries',
              tag: tag,
              data: {'deliveryId': deliveryId, 'action': 'track_delivery'},
            );
          }
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
        'status': 'Completed',
        'completedAt': FieldValue.serverTimestamp(),
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
            // Notify provider
            await _notificationService.createNotification(
              userId: fromUserId,
              title: '🚚 Delivery Completed!',
              message:
                  'Your delivery of "$itemName" has been completed successfully.',
              type: 'Deliveries',
              tag: '#Completed',
              data: {'deliveryId': deliveryId, 'action': 'view_delivery'},
            );

            // Notify receiver
            await _notificationService.createNotification(
              userId: toUserId,
              title: '📦 Item Delivered!',
              message: 'Your "$itemName" has been delivered successfully.',
              type: 'Deliveries',
              tag: '#Delivered',
              data: {'deliveryId': deliveryId, 'action': 'view_delivery'},
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
