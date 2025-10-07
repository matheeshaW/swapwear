import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery_model.dart';
import 'notifications_manager.dart';

class DeliveryService {
  final FirebaseFirestore _db;

  DeliveryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Create a new delivery record when user sets delivery location
  Future<String> createDelivery({
    required String swapId,
    required String userId,
    required String itemName,
    required String deliveryLocation,
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      print('🚚 Creating delivery for swap: $swapId');

      final deliveryRef = _db.collection('deliveries').doc();

      final delivery = DeliveryModel(
        swapId: swapId,
        userId: userId,
        itemName: itemName,
        deliveryLocation: deliveryLocation,
        status: 'Pending',
        step: 1,
        lastUpdated: null, // Do not set FieldValue here
        trackingNote: 'Delivery location set - awaiting admin approval',
        fromUserId: fromUserId,
        toUserId: toUserId,
      );

      final data = delivery.toMap();
      data['lastUpdated'] = FieldValue.serverTimestamp();

      await deliveryRef.set(data);
      print('✅ Delivery created: ${deliveryRef.id}');

      // Send notification when delivery location is set
      try {
        await NotificationsManager.instance.addTestNotification(
          userId: toUserId,
          type: 'Deliveries',
          title: 'Delivery Location Set! 📍',
          message:
              'Delivery location has been set for your swap. Awaiting admin approval.',
          tag: '#DeliveryLocation',
        );
        print('✅ Delivery location notification sent to user: $toUserId');
      } catch (e) {
        print('❌ Failed to send delivery location notification: $e');
      }

      return deliveryRef.id;
    } catch (e) {
      print('❌ Error creating delivery: $e');
      throw Exception('Failed to create delivery: $e');
    }
  }

  /// Update delivery status (admin only)
  Future<void> updateDeliveryStatus({
    required String deliveryId,
    required String newStatus,
    String? trackingNote,
  }) async {
    try {
      final deliveryRef = _db.collection('deliveries').doc(deliveryId);
      final deliveryDoc = await deliveryRef.get();

      if (!deliveryDoc.exists) {
        throw Exception('Delivery not found');
      }

      final delivery = DeliveryModel.fromMap(
        deliveryDoc.data()!,
        deliveryDoc.id,
      );

      if (!delivery.canUpdateStatus()) {
        throw Exception('Cannot update completed delivery');
      }

      // Determine step number based on status
      int step;
      switch (newStatus) {
        case 'Pending':
          step = 1;
          break;
        case 'Approved':
          step = 2;
          break;
        case 'Out for Delivery':
          step = 3;
          break;
        case 'Completed':
          step = 4;
          break;
        default:
          step = delivery.step;
      }

      await deliveryRef.update({
        'status': newStatus,
        'step': step,
        'lastUpdated': FieldValue.serverTimestamp(),
        'trackingNote': trackingNote ?? _getDefaultTrackingNote(newStatus),
      });

      // Send FCM notification to both users
      await _sendDeliveryNotification(
        deliveryId: deliveryId,
        delivery: delivery.copyWith(
          status: newStatus,
          step: step,
          trackingNote: trackingNote ?? _getDefaultTrackingNote(newStatus),
        ),
      );
    } catch (e) {
      throw Exception('Failed to update delivery status: $e');
    }
  }

  /// Get delivery by ID
  Future<DeliveryModel?> getDeliveryById(String deliveryId) async {
    try {
      final doc = await _db.collection('deliveries').doc(deliveryId).get();
      if (!doc.exists) return null;
      return DeliveryModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get delivery: $e');
    }
  }

  /// Get delivery by swap ID
  Future<DeliveryModel?> getDeliveryBySwapId(String swapId) async {
    try {
      print('🔍 Looking for delivery with swapId: $swapId');

      final querySnapshot = await _db
          .collection('deliveries')
          .where('swapId', isEqualTo: swapId)
          .limit(1)
          .get();

      print('📊 Query returned ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isEmpty) {
        print('❌ No delivery found for swapId: $swapId');
        return null;
      }

      final doc = querySnapshot.docs.first;
      print('✅ Found delivery: ${doc.id}');

      return DeliveryModel.fromMap(doc.data(), doc.id);
    } catch (e) {
      print('❌ Error getting delivery by swap ID: $e');
      throw Exception('Failed to get delivery by swap ID: $e');
    }
  }

  /// Stream delivery updates for a specific delivery
  Stream<DeliveryModel?> streamDelivery(String deliveryId) {
    return _db.collection('deliveries').doc(deliveryId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return DeliveryModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  /// Stream delivery updates by swap ID
  Stream<DeliveryModel?> streamDeliveryBySwapId(String swapId) {
    return _db
        .collection('deliveries')
        .where('swapId', isEqualTo: swapId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return DeliveryModel.fromMap(doc.data(), doc.id);
        });
  }

  /// Stream all deliveries for admin dashboard
  Stream<List<DeliveryModel>> streamAllDeliveries() {
    return _db
        .collection('deliveries')
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Stream deliveries for a specific user
  Stream<List<DeliveryModel>> streamUserDeliveries(String userId) {
    return _db
        .collection('deliveries')
        .where(
          Filter.or(
            Filter('fromUserId', isEqualTo: userId),
            Filter('toUserId', isEqualTo: userId),
          ),
        )
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Send notification when delivery status changes
  Future<void> _sendDeliveryNotification({
    required String deliveryId,
    required DeliveryModel delivery,
  }) async {
    try {
      // Send notification to both users using NotificationsManager
      final title = 'Delivery Update';
      final message = '${delivery.itemName} status: ${delivery.status}';

      // Notify the sender
      await NotificationsManager.instance.addTestNotification(
        userId: delivery.fromUserId,
        type: 'Deliveries',
        title: title,
        message: message,
        tag: '#DeliveryUpdate',
      );

      // Notify the recipient
      await NotificationsManager.instance.addTestNotification(
        userId: delivery.toUserId,
        type: 'Deliveries',
        title: title,
        message: message,
        tag: '#DeliveryUpdate',
      );

      print('✅ Delivery notifications sent to both users');
    } catch (e) {
      // Don't throw error for notification failures
      print('❌ Failed to send delivery notifications: $e');
    }
  }

  /// Get default tracking note based on status
  String _getDefaultTrackingNote(String status) {
    switch (status) {
      case 'Pending':
        return 'Delivery created - awaiting admin approval';
      case 'Approved':
        return 'Swap approved by admin - preparing for pickup';
      case 'Out for Delivery':
        return 'Package picked up by courier - in transit';
      case 'Completed':
        return 'Delivery completed successfully';
      default:
        return 'Status updated';
    }
  }

  /// Complete delivery (mark as completed)
  Future<void> completeDelivery(String deliveryId) async {
    await updateDeliveryStatus(
      deliveryId: deliveryId,
      newStatus: 'Completed',
      trackingNote: 'Delivery completed - swap successful',
    );
  }

  /// Get delivery statistics for admin dashboard
  Future<Map<String, int>> getDeliveryStats() async {
    try {
      final snapshot = await _db.collection('deliveries').get();
      final deliveries = snapshot.docs
          .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
          .toList();

      return {
        'total': deliveries.length,
        'pending': deliveries.where((d) => d.status == 'Pending').length,
        'approved': deliveries.where((d) => d.status == 'Approved').length,
        'out_for_delivery': deliveries
            .where((d) => d.status == 'Out for Delivery')
            .length,
        'completed': deliveries.where((d) => d.status == 'Completed').length,
      };
    } catch (e) {
      throw Exception('Failed to get delivery stats: $e');
    }
  }
}
