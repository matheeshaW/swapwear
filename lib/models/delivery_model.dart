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

  // Dual delivery support
  final String ownerId; // The user who owns this specific delivery record
  final String partnerId; // The other user in the swap
  final String swapPairId; // Links both delivery records together

  // Enhanced location and tracking data
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? pickupAddress;
  final String? deliveryAddress;
  final double? distanceKm;
  final double? co2SavedKg;
  final String? routePolyline;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

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
    required this.ownerId,
    required this.partnerId,
    required this.swapPairId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.pickupAddress,
    this.deliveryAddress,
    this.distanceKm,
    this.co2SavedKg,
    this.routePolyline,
    this.pickedUpAt,
    this.deliveredAt,
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
      ownerId: map['ownerId'] ?? '',
      partnerId: map['partnerId'] ?? '',
      swapPairId: map['swapPairId'] ?? '',
      pickupLatitude: map['pickupLatitude']?.toDouble(),
      pickupLongitude: map['pickupLongitude']?.toDouble(),
      deliveryLatitude: map['deliveryLatitude']?.toDouble(),
      deliveryLongitude: map['deliveryLongitude']?.toDouble(),
      pickupAddress: map['pickupAddress'],
      deliveryAddress: map['deliveryAddress'],
      distanceKm: map['distanceKm']?.toDouble(),
      co2SavedKg: map['co2SavedKg']?.toDouble(),
      routePolyline: map['routePolyline'],
      pickedUpAt: map['pickedUpAt'] != null
          ? (map['pickedUpAt'] as Timestamp).toDate()
          : null,
      deliveredAt: map['deliveredAt'] != null
          ? (map['deliveredAt'] as Timestamp).toDate()
          : null,
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
      'ownerId': ownerId,
      'partnerId': partnerId,
      'swapPairId': swapPairId,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'distanceKm': distanceKm,
      'co2SavedKg': co2SavedKg,
      'routePolyline': routePolyline,
      'pickedUpAt': pickedUpAt != null ? Timestamp.fromDate(pickedUpAt!) : null,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
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
    String? ownerId,
    String? partnerId,
    String? swapPairId,
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? pickupAddress,
    String? deliveryAddress,
    double? distanceKm,
    double? co2SavedKg,
    String? routePolyline,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
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
      ownerId: ownerId ?? this.ownerId,
      partnerId: partnerId ?? this.partnerId,
      swapPairId: swapPairId ?? this.swapPairId,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      distanceKm: distanceKm ?? this.distanceKm,
      co2SavedKg: co2SavedKg ?? this.co2SavedKg,
      routePolyline: routePolyline ?? this.routePolyline,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  // Status progression logic
  static const List<String> statusSteps = [
    'Pending',
    'Approved',
    'Picked Up',
    'In Transit',
    'Delivered',
  ];

  int get statusStep {
    return statusSteps.indexOf(status);
  }

  bool get isCompleted => status == 'Delivered';
  bool get isInTransit => status == 'In Transit';
  bool get isPickedUp => status == 'Picked Up';
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
