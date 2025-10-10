import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatsModel {
  final String userId;
  final int ecoPoints;
  final int totalSwaps;
  final List<String> badges;
  final DateTime lastUpdated;
  final double co2Saved;
  final double waterSaved;
  final int itemsRecycled;
  final Map<String, Map<String, double>> monthlyStats;

  UserStatsModel({
    required this.userId,
    required this.ecoPoints,
    required this.totalSwaps,
    required this.badges,
    required this.lastUpdated,
    required this.co2Saved,
    required this.waterSaved,
    required this.itemsRecycled,
    required this.monthlyStats,
  });

  factory UserStatsModel.fromMap(Map<String, dynamic> map, String userId) {
    return UserStatsModel(
      userId: userId,
      ecoPoints: map['ecoPoints'] ?? 0,
      totalSwaps: map['totalSwaps'] ?? 0,
      badges: List<String>.from(map['badges'] ?? []),
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      co2Saved: (map['co2Saved'] ?? 0).toDouble(),
      waterSaved: (map['waterSaved'] ?? 0).toDouble(),
      itemsRecycled: map['itemsRecycled'] ?? 0,
      monthlyStats: _parseMonthlyStats(map['monthlyStats']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ecoPoints': ecoPoints,
      'totalSwaps': totalSwaps,
      'badges': badges,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'co2Saved': co2Saved,
      'waterSaved': waterSaved,
      'itemsRecycled': itemsRecycled,
      'monthlyStats': monthlyStats,
    };
  }

  UserStatsModel copyWith({
    String? userId,
    int? ecoPoints,
    int? totalSwaps,
    List<String>? badges,
    DateTime? lastUpdated,
    double? co2Saved,
    double? waterSaved,
    int? itemsRecycled,
    Map<String, Map<String, double>>? monthlyStats,
  }) {
    return UserStatsModel(
      userId: userId ?? this.userId,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      totalSwaps: totalSwaps ?? this.totalSwaps,
      badges: badges ?? this.badges,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      co2Saved: co2Saved ?? this.co2Saved,
      waterSaved: waterSaved ?? this.waterSaved,
      itemsRecycled: itemsRecycled ?? this.itemsRecycled,
      monthlyStats: monthlyStats ?? this.monthlyStats,
    );
  }

  static Map<String, Map<String, double>> _parseMonthlyStats(
    dynamic monthlyStatsData,
  ) {
    if (monthlyStatsData == null) return {};

    try {
      if (monthlyStatsData is Map) {
        return Map<String, Map<String, double>>.from(
          monthlyStatsData.map((key, value) {
            if (value is Map) {
              return MapEntry(
                key.toString(),
                Map<String, double>.from(
                  value.map((k, v) => MapEntry(k.toString(), v.toDouble())),
                ),
              );
            } else {
              // If value is not a Map, return empty map for this key
              return MapEntry(key.toString(), <String, double>{});
            }
          }),
        );
      }
    } catch (e) {
      print('Error parsing monthly stats: $e');
    }

    return {};
  }
}
