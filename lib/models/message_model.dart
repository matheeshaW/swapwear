import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class MessageModel {
  final String? id;
  final String senderId;
  final String text;
  final Timestamp? timestamp;
  final bool seen;

  const MessageModel({
    this.id,
    required this.senderId,
    required this.text,
    this.timestamp,
    required this.seen,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String,
      text: map['text'] as String,
      timestamp: map['timestamp'] as Timestamp?,
      seen: map['seen'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'seen': seen,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    Timestamp? timestamp,
    bool? seen,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      seen: seen ?? this.seen,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, senderId: $senderId, text: $text, timestamp: $timestamp, seen: $seen)';
  }
}
