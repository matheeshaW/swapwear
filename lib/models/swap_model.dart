import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class SwapModel {
  final String? id;
  final String listingOfferedId;
  final String listingRequestedId;
  final String fromUserId;
  final String toUserId;
  final String status; // "pending" | "accepted" | "rejected" | "completed"
  final String chatId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

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
    );
  }

  @override
  String toString() {
    return 'SwapModel(id: $id, listingOfferedId: $listingOfferedId, listingRequestedId: $listingRequestedId, fromUserId: $fromUserId, toUserId: $toUserId, status: $status, chatId: $chatId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
