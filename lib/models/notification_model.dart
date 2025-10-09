import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;
  final String title;
  final String message;
  final String type; // 'Swaps', 'Badges', 'Deliveries'
  final String? tag;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final Map<String, dynamic>? data;

  NotificationModel({
    this.id,
    required this.title,
    required this.message,
    required this.type,
    this.tag,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.data,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'Swaps',
      tag: map['tag'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      imageUrl: map['imageUrl'],
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'tag': tag,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'data': data,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? tag,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      tag: tag ?? this.tag,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
    );
  }

  // Get icon based on notification type
  String get icon {
    switch (type) {
      case 'Swaps':
        return '✅';
      case 'Badges':
        return '🏆';
      case 'Deliveries':
        return '🚚';
      case 'Listings':
        return '📦';
      case 'Wishlist':
        return '❤️';
      case 'Login':
        return '🔐';
      case 'System':
        return '⚙️';
      default:
        return '🔔';
    }
  }

  // Get color based on notification type
  String get colorHex {
    switch (type) {
      case 'Swaps':
        return '#10B981'; // Green
      case 'Badges':
        return '#F59E0B'; // Orange
      case 'Deliveries':
        return '#3B82F6'; // Blue
      case 'Listings':
        return '#8B5CF6'; // Purple
      case 'Wishlist':
        return '#EC4899'; // Pink
      case 'Login':
        return '#06B6D4'; // Cyan
      case 'System':
        return '#6B7280'; // Gray
      default:
        return '#6B7280'; // Gray
    }
  }

  // Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
    }
  }

  // Check if notification is from today
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  // Check if notification is from yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return timestamp.year == yesterday.year &&
        timestamp.month == yesterday.month &&
        timestamp.day == yesterday.day;
  }

  // Get time group for display
  String get timeGroup {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return 'Older';
  }
}
