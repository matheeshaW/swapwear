import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryModel {
  final String? id;
  final String swapId;
  final String itemName;
  final String providerId;
  final String receiverId;
  final String status;
  final String currentLocation;
  final DateTime? estimatedDelivery;
  final DateTime? lastUpdated;
  final String? itemImageUrl;
  final String? providerName;
  final String? receiverName;

  DeliveryModel({
    this.id,
    required this.swapId,
    required this.itemName,
    required this.providerId,
    required this.receiverId,
    required this.status,
    required this.currentLocation,
    this.estimatedDelivery,
    this.lastUpdated,
    this.itemImageUrl,
    this.providerName,
    this.receiverName,
  });

  factory DeliveryModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryModel(
      id: id,
      swapId: map['swapId'] ?? '',
      itemName: map['itemName'] ?? '',
      providerId: map['providerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: map['status'] ?? 'Pending',
      currentLocation: map['currentLocation'] ?? '',
      estimatedDelivery: map['estimatedDelivery'] != null
          ? (map['estimatedDelivery'] as Timestamp).toDate()
          : null,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
      itemImageUrl: map['itemImageUrl'],
      providerName: map['providerName'],
      receiverName: map['receiverName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'swapId': swapId,
      'itemName': itemName,
      'providerId': providerId,
      'receiverId': receiverId,
      'status': status,
      'currentLocation': currentLocation,
      'estimatedDelivery': estimatedDelivery != null
          ? Timestamp.fromDate(estimatedDelivery!)
          : null,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : FieldValue.serverTimestamp(),
      'itemImageUrl': itemImageUrl,
      'providerName': providerName,
      'receiverName': receiverName,
    };
  }

  DeliveryModel copyWith({
    String? id,
    String? swapId,
    String? itemName,
    String? providerId,
    String? receiverId,
    String? status,
    String? currentLocation,
    DateTime? estimatedDelivery,
    DateTime? lastUpdated,
    String? itemImageUrl,
    String? providerName,
    String? receiverName,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      swapId: swapId ?? this.swapId,
      itemName: itemName ?? this.itemName,
      providerId: providerId ?? this.providerId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      providerName: providerName ?? this.providerName,
      receiverName: receiverName ?? this.receiverName,
    );
  }

  // Status progression logic
  static const List<String> statusSteps = [
    'Pending',
    'Approved',
    'Out for Delivery',
    'Completed',
  ];

  int get statusStep {
    return statusSteps.indexOf(status);
  }

  bool get isCompleted => status == 'Completed';
  bool get isOutForDelivery => status == 'Out for Delivery';
  bool get isApproved => status == 'Approved';
  bool get isPending => status == 'Pending';

  String get nextStatus {
    final currentIndex = statusSteps.indexOf(status);
    if (currentIndex < statusSteps.length - 1) {
      return statusSteps[currentIndex + 1];
    }
    return status;
  }

  bool canUpdateTo(String newStatus) {
    final currentIndex = statusSteps.indexOf(status);
    final newIndex = statusSteps.indexOf(newStatus);
    return newIndex > currentIndex && newIndex <= currentIndex + 1;
  }
}

