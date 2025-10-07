import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class DeliveryModel {
  final String? id;
  final String swapId;
  final String userId;
  final String itemName;
  final String deliveryLocation;
  final String
  status; // "Pending" | "Approved" | "Out for Delivery" | "Completed"
  final int step; // 1-4 corresponding to status
  final Timestamp? lastUpdated;
  final String? trackingNote;
  final String fromUserId;
  final String toUserId;

  const DeliveryModel({
    this.id,
    required this.swapId,
    required this.userId,
    required this.itemName,
    required this.deliveryLocation,
    required this.status,
    required this.step,
    this.lastUpdated,
    this.trackingNote,
    required this.fromUserId,
    required this.toUserId,
  });

  factory DeliveryModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryModel(
      id: id,
      swapId: map['swapId'] as String,
      userId: map['userId'] as String,
      itemName: map['itemName'] as String,
      deliveryLocation: map['deliveryLocation'] as String,
      status: map['status'] as String,
      step: map['step'] as int,
      lastUpdated: map['lastUpdated'] as Timestamp?,
      trackingNote: map['trackingNote'] as String?,
      fromUserId: map['fromUserId'] as String,
      toUserId: map['toUserId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'swapId': swapId,
      'userId': userId,
      'itemName': itemName,
      'deliveryLocation': deliveryLocation,
      'status': status,
      'step': step,
      'lastUpdated': lastUpdated,
      'trackingNote': trackingNote,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
    };
  }

  DeliveryModel copyWith({
    String? id,
    String? swapId,
    String? userId,
    String? itemName,
    String? deliveryLocation,
    String? status,
    int? step,
    Timestamp? lastUpdated,
    String? trackingNote,
    String? fromUserId,
    String? toUserId,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      swapId: swapId ?? this.swapId,
      userId: userId ?? this.userId,
      itemName: itemName ?? this.itemName,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      status: status ?? this.status,
      step: step ?? this.step,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      trackingNote: trackingNote ?? this.trackingNote,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
    );
  }

  // Helper method to get the next status
  String getNextStatus() {
    switch (status) {
      case 'Pending':
        return 'Approved';
      case 'Approved':
        return 'Out for Delivery';
      case 'Out for Delivery':
        return 'Completed';
      default:
        return status;
    }
  }

  // Helper method to get the next step number
  int getNextStepNumber() {
    return step < 4 ? step + 1 : step;
  }

  // Helper method to check if delivery can be updated
  bool canUpdateStatus() {
    return status != 'Completed';
  }

  @override
  String toString() {
    return 'DeliveryModel(id: $id, swapId: $swapId, userId: $userId, itemName: $itemName, deliveryLocation: $deliveryLocation, status: $status, step: $step, lastUpdated: $lastUpdated, trackingNote: $trackingNote, fromUserId: $fromUserId, toUserId: $toUserId)';
  }
}
