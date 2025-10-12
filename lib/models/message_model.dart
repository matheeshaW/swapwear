import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class MessageModel {
  final String? id;
  final String senderId;
  final String? receiverId;
  final String text;
  final Timestamp? timestamp;
  final bool isRead;

  const MessageModel({
    this.id,
    required this.senderId,
    this.receiverId,
    required this.text,
    this.timestamp,
    this.isRead = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String?,
      text: map['text'] as String,
      timestamp: map['timestamp'] as Timestamp?,
      isRead: map['isRead'] as bool? ?? map['seen'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    Timestamp? timestamp,
    bool? isRead,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, senderId: $senderId, receiverId: $receiverId, text: $text, timestamp: $timestamp, isRead: $isRead)';
  }
}
