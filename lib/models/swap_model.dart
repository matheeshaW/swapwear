import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class SwapModel {
  final String? id;
  final String listingOfferedId;
  final String listingRequestedId;
  final String fromUserId;
  final String toUserId;
  final String
  status; // "pending" | "accepted" | "confirmed" | "ready_for_delivery" | "rejected" | "completed"
  final String chatId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final List<String>? deletedBy; // Track which users have deleted this swap

  // Dual location fields
  final Map<String, dynamic>? user01Location; // {lat, lng, address}
  final Map<String, dynamic>? user02Location; // {lat, lng, address}
  final bool user01LocationConfirmed;
  final bool user02LocationConfirmed;
  final bool bothConfirmed;
  final String deliveryStatus; // "Pending" | "InProgress" | "Completed"

  const SwapModel({
    this.id,
    required this.listingOfferedId,
    required this.listingRequestedId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.chatId,
    this.createdAt,
    this.updatedAt,
    this.deletedBy,
    this.user01Location,
    this.user02Location,
    this.user01LocationConfirmed = false,
    this.user02LocationConfirmed = false,
    this.bothConfirmed = false,
    this.deliveryStatus = 'Pending',
  });

  factory SwapModel.fromMap(Map<String, dynamic> map, String id) {
    return SwapModel(
      id: id,
      listingOfferedId: map['listingOfferedId'] as String,
      listingRequestedId: map['listingRequestedId'] as String,
      fromUserId: map['fromUserId'] as String,
      toUserId: map['toUserId'] as String,
      status: map['status'] as String,
      chatId: map['chatId'] as String,
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
      deletedBy: map['deletedBy'] != null
          ? List<String>.from(map['deletedBy'] as List)
          : null,
      user01Location: map['user01Location'] as Map<String, dynamic>?,
      user02Location: map['user02Location'] as Map<String, dynamic>?,
      user01LocationConfirmed: map['user01LocationConfirmed'] as bool? ?? false,
      user02LocationConfirmed: map['user02LocationConfirmed'] as bool? ?? false,
      bothConfirmed: map['bothConfirmed'] as bool? ?? false,
      deliveryStatus: map['deliveryStatus'] as String? ?? 'Pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingOfferedId': listingOfferedId,
      'listingRequestedId': listingRequestedId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status,
      'chatId': chatId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedBy': deletedBy,
      'user01Location': user01Location,
      'user02Location': user02Location,
      'user01LocationConfirmed': user01LocationConfirmed,
      'user02LocationConfirmed': user02LocationConfirmed,
      'bothConfirmed': bothConfirmed,
      'deliveryStatus': deliveryStatus,
    };
  }

  SwapModel copyWith({
    String? id,
    String? listingOfferedId,
    String? listingRequestedId,
    String? fromUserId,
    String? toUserId,
    String? status,
    String? chatId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    List<String>? deletedBy,
    Map<String, dynamic>? user01Location,
    Map<String, dynamic>? user02Location,
    bool? user01LocationConfirmed,
    bool? user02LocationConfirmed,
    bool? bothConfirmed,
    String? deliveryStatus,
  }) {
    return SwapModel(
      id: id ?? this.id,
      listingOfferedId: listingOfferedId ?? this.listingOfferedId,
      listingRequestedId: listingRequestedId ?? this.listingRequestedId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      status: status ?? this.status,
      chatId: chatId ?? this.chatId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      user01Location: user01Location ?? this.user01Location,
      user02Location: user02Location ?? this.user02Location,
      user01LocationConfirmed:
          user01LocationConfirmed ?? this.user01LocationConfirmed,
      user02LocationConfirmed:
          user02LocationConfirmed ?? this.user02LocationConfirmed,
      bothConfirmed: bothConfirmed ?? this.bothConfirmed,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  @override
  String toString() {
    return 'SwapModel(id: $id, listingOfferedId: $listingOfferedId, listingRequestedId: $listingRequestedId, fromUserId: $fromUserId, toUserId: $toUserId, status: $status, chatId: $chatId, createdAt: $createdAt, updatedAt: $updatedAt, deletedBy: $deletedBy, user01Location: $user01Location, user02Location: $user02Location, user01LocationConfirmed: $user01LocationConfirmed, user02LocationConfirmed: $user02LocationConfirmed, bothConfirmed: $bothConfirmed, deliveryStatus: $deliveryStatus)';
  }
}
