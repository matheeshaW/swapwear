import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardModel {
  final String userId;
  final String username;
  final int ecoPoints;
  final int rank;
  final DateTime lastUpdated;

  LeaderboardModel({
    required this.userId,
    required this.username,
    required this.ecoPoints,
    required this.rank,
    required this.lastUpdated,
  });

  factory LeaderboardModel.fromMap(Map<String, dynamic> map, String userId) {
    return LeaderboardModel(
      userId: userId,
      username: map['username'] ?? '',
      ecoPoints: map['ecoPoints'] ?? 0,
      rank: map['rank'] ?? 0,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'ecoPoints': ecoPoints,
      'rank': rank,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  LeaderboardModel copyWith({
    String? userId,
    String? username,
    int? ecoPoints,
    int? rank,
    DateTime? lastUpdated,
  }) {
    return LeaderboardModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      rank: rank ?? this.rank,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

