import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_stats_model.dart';
import '../models/leaderboard_model.dart';

class AchievementsService {
  static final AchievementsService _instance = AchievementsService._internal();
  factory AchievementsService() => _instance;
  AchievementsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Badge definitions
  static const Map<String, Map<String, dynamic>> badgeDefinitions = {
    'First Swap': {
      'icon': '⭐',
      'name': 'First Swap',
      'description': 'Complete your first swap',
      'requirement': {'type': 'swaps', 'value': 1},
    },
    '5 Swaps': {
      'icon': '👕',
      'name': '5 Swaps',
      'description': 'Complete 5 swaps',
      'requirement': {'type': 'swaps', 'value': 5},
    },
    'Eco Hero': {
      'icon': '🌱',
      'name': 'Eco Hero',
      'description': 'Complete 10 swaps',
      'requirement': {'type': 'swaps', 'value': 10},
    },
    'Champion': {
      'icon': '🏆',
      'name': 'Champion',
      'description': 'Complete 50 swaps',
      'requirement': {'type': 'swaps', 'value': 50},
    },
    'Premium': {
      'icon': '💎',
      'name': 'Premium',
      'description': 'Complete 100 swaps',
      'requirement': {'type': 'swaps', 'value': 100},
    },
    'Global': {
      'icon': '🌍',
      'name': 'Global',
      'description': 'Complete 200 swaps',
      'requirement': {'type': 'swaps', 'value': 200},
    },
  };

  // Get user stats
  Future<UserStatsModel?> getUserStats(String userId) async {
    try {
      final doc = await _db.collection('userStats').doc(userId).get();
      if (doc.exists) {
        return UserStatsModel.fromMap(doc.data()!, userId);
      }
      return null;
    } catch (e) {
      print('Error getting user stats: $e');
      return null;
    }
  }

  // Stream user stats
  Stream<UserStatsModel?> streamUserStats(String userId) {
    return _db.collection('userStats').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserStatsModel.fromMap(doc.data()!, userId);
      }
      return null;
    });
  }

  // Initialize user stats
  Future<void> initializeUserStats(String userId) async {
    try {
      final doc = await _db.collection('userStats').doc(userId).get();
      if (!doc.exists) {
        await _db.collection('userStats').doc(userId).set({
          'ecoPoints': 0,
          'totalSwaps': 0,
          'badges': [],
          'lastUpdated': FieldValue.serverTimestamp(),
          'co2Saved': 0.0,
          'waterSaved': 0.0,
          'itemsRecycled': 0,
          'monthlyStats': {},
        });
        print('User stats initialized for $userId');
      } else {
        // Check if the document has all required fields
        final data = doc.data()!;
        final needsUpdate =
            !data.containsKey('co2Saved') ||
            !data.containsKey('waterSaved') ||
            !data.containsKey('itemsRecycled') ||
            !data.containsKey('monthlyStats');

        if (needsUpdate) {
          print('Updating user stats with missing fields for $userId');
          await _db.collection('userStats').doc(userId).update({
            'co2Saved': data['co2Saved'] ?? 0.0,
            'waterSaved': data['waterSaved'] ?? 0.0,
            'itemsRecycled': data['itemsRecycled'] ?? 0,
            'monthlyStats': data['monthlyStats'] ?? {},
          });
        }
      }
    } catch (e) {
      print('Error initializing user stats: $e');
    }
  }

  // Update user stats and check for new badges
  Future<List<String>> updateUserStats({
    required String userId,
    int? ecoPointsToAdd,
    int? swapsToAdd,
    double? co2ToAdd,
    double? waterToAdd,
    int? itemsToAdd,
  }) async {
    try {
      print(
        'Updating user stats for $userId: +${ecoPointsToAdd ?? 0} points, +${swapsToAdd ?? 0} swaps',
      );

      final userStats = await getUserStats(userId);
      if (userStats == null) {
        print('User stats not found, initializing...');
        await initializeUserStats(userId);
        // Try to get stats again after initialization
        final newUserStats = await getUserStats(userId);
        if (newUserStats == null) {
          print('Failed to initialize user stats');
          return [];
        }

        final newEcoPoints = newUserStats.ecoPoints + (ecoPointsToAdd ?? 0);
        final newTotalSwaps = newUserStats.totalSwaps + (swapsToAdd ?? 0);
        final newCo2Saved = newUserStats.co2Saved + (co2ToAdd ?? 0.0);
        final newWaterSaved = newUserStats.waterSaved + (waterToAdd ?? 0.0);
        final newItemsRecycled = newUserStats.itemsRecycled + (itemsToAdd ?? 0);

        // Update monthly stats
        final currentMonth = DateTime.now().toIso8601String().substring(
          0,
          7,
        ); // YYYY-MM
        final updatedMonthlyStats = Map<String, Map<String, double>>.from(
          newUserStats.monthlyStats,
        );
        if (!updatedMonthlyStats.containsKey(currentMonth)) {
          updatedMonthlyStats[currentMonth] = {
            'co2': 0.0,
            'water': 0.0,
            'items': 0.0,
          };
        }
        updatedMonthlyStats[currentMonth]!['co2'] =
            (updatedMonthlyStats[currentMonth]!['co2'] ?? 0.0) +
            (co2ToAdd ?? 0.0);
        updatedMonthlyStats[currentMonth]!['water'] =
            (updatedMonthlyStats[currentMonth]!['water'] ?? 0.0) +
            (waterToAdd ?? 0.0);
        updatedMonthlyStats[currentMonth]!['items'] =
            (updatedMonthlyStats[currentMonth]!['items'] ?? 0.0) +
            (itemsToAdd ?? 0.0);

        // Check for new badges
        final newBadges = _checkForNewBadges(
          newTotalSwaps,
          newEcoPoints,
          newUserStats.badges,
        );

        // Update user stats
        await _db.collection('userStats').doc(userId).update({
          'ecoPoints': newEcoPoints,
          'totalSwaps': newTotalSwaps,
          'badges': FieldValue.arrayUnion(newBadges),
          'lastUpdated': FieldValue.serverTimestamp(),
          'co2Saved': newCo2Saved,
          'waterSaved': newWaterSaved,
          'itemsRecycled': newItemsRecycled,
          'monthlyStats': updatedMonthlyStats,
        });

        // Update leaderboard
        await _updateLeaderboard(userId, newEcoPoints);

        print(
          'Updated stats: $newEcoPoints points, $newTotalSwaps swaps, badges: $newBadges',
        );
        return newBadges;
      }

      final newEcoPoints = userStats.ecoPoints + (ecoPointsToAdd ?? 0);
      final newTotalSwaps = userStats.totalSwaps + (swapsToAdd ?? 0);
      final newCo2Saved = userStats.co2Saved + (co2ToAdd ?? 0.0);
      final newWaterSaved = userStats.waterSaved + (waterToAdd ?? 0.0);
      final newItemsRecycled = userStats.itemsRecycled + (itemsToAdd ?? 0);

      // Update monthly stats
      final currentMonth = DateTime.now().toIso8601String().substring(
        0,
        7,
      ); // YYYY-MM
      final updatedMonthlyStats = Map<String, Map<String, double>>.from(
        userStats.monthlyStats,
      );
      if (!updatedMonthlyStats.containsKey(currentMonth)) {
        updatedMonthlyStats[currentMonth] = {
          'co2': 0.0,
          'water': 0.0,
          'items': 0.0,
        };
      }
      updatedMonthlyStats[currentMonth]!['co2'] =
          (updatedMonthlyStats[currentMonth]!['co2'] ?? 0.0) +
          (co2ToAdd ?? 0.0);
      updatedMonthlyStats[currentMonth]!['water'] =
          (updatedMonthlyStats[currentMonth]!['water'] ?? 0.0) +
          (waterToAdd ?? 0.0);
      updatedMonthlyStats[currentMonth]!['items'] =
          (updatedMonthlyStats[currentMonth]!['items'] ?? 0.0) +
          (itemsToAdd ?? 0.0);

      // Check for new badges
      final newBadges = _checkForNewBadges(
        newTotalSwaps,
        newEcoPoints,
        userStats.badges,
      );

      // Update user stats
      await _db.collection('userStats').doc(userId).update({
        'ecoPoints': newEcoPoints,
        'totalSwaps': newTotalSwaps,
        'badges': FieldValue.arrayUnion(newBadges),
        'lastUpdated': FieldValue.serverTimestamp(),
        'co2Saved': newCo2Saved,
        'waterSaved': newWaterSaved,
        'itemsRecycled': newItemsRecycled,
        'monthlyStats': updatedMonthlyStats,
      });

      // Update leaderboard
      await _updateLeaderboard(userId, newEcoPoints);

      print(
        'Updated stats: $newEcoPoints points, $newTotalSwaps swaps, badges: $newBadges',
      );
      return newBadges;
    } catch (e) {
      print('Error updating user stats: $e');
      return [];
    }
  }

  // Check for new badges based on current stats
  List<String> _checkForNewBadges(
    int totalSwaps,
    int ecoPoints,
    List<String> currentBadges,
  ) {
    final newBadges = <String>[];

    for (final entry in badgeDefinitions.entries) {
      final badgeId = entry.key;
      final badge = entry.value;
      final requirement = badge['requirement'] as Map<String, dynamic>;

      if (!currentBadges.contains(badgeId)) {
        final type = requirement['type'] as String;
        final value = requirement['value'] as int;

        bool earned = false;
        if (type == 'swaps' && totalSwaps >= value) {
          earned = true;
        } else if (type == 'ecoPoints' && ecoPoints >= value) {
          earned = true;
        }

        if (earned) {
          newBadges.add(badgeId);
        }
      }
    }

    return newBadges;
  }

  // Update leaderboard
  Future<void> _updateLeaderboard(String userId, int ecoPoints) async {
    try {
      // Get user info
      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final username = userData?['name'] ?? 'User';

      // Update leaderboard entry
      await _db.collection('leaderboard').doc(userId).set({
        'username': username,
        'ecoPoints': ecoPoints,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update ranks
      await _updateRanks();
    } catch (e) {
      print('Error updating leaderboard: $e');
    }
  }

  // Update all ranks in leaderboard
  Future<void> _updateRanks() async {
    try {
      final snapshot = await _db
          .collection('leaderboard')
          .orderBy('ecoPoints', descending: true)
          .get();

      final batch = _db.batch();
      for (int i = 0; i < snapshot.docs.length; i++) {
        batch.update(snapshot.docs[i].reference, {'rank': i + 1});
      }
      await batch.commit();
    } catch (e) {
      print('Error updating ranks: $e');
    }
  }

  // Get leaderboard
  Future<List<LeaderboardModel>> getLeaderboard({int limit = 10}) async {
    try {
      final snapshot = await _db
          .collection('leaderboard')
          .orderBy('ecoPoints', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }

  // Stream leaderboard
  Stream<List<LeaderboardModel>> streamLeaderboard({int limit = 10}) {
    return _db
        .collection('leaderboard')
        .orderBy('ecoPoints', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaderboardModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get user rank
  Future<int> getUserRank(String userId) async {
    try {
      final doc = await _db.collection('leaderboard').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['rank'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting user rank: $e');
      return 0;
    }
  }

  // Award eco points for swap completion
  Future<List<String>> awardSwapCompletion(String userId) async {
    try {
      print('Awarding swap completion for user: $userId');
      final result = await updateUserStats(
        userId: userId,
        ecoPointsToAdd: 10, // 10 points per swap
        swapsToAdd: 1,
        co2ToAdd: 0.5, // 0.5 kg CO2 saved per swap
        waterToAdd: 20.0, // 20L water saved per swap
        itemsToAdd: 1, // 1 item recycled per swap
      );
      print('Awarded badges: $result');
      return result;
    } catch (e) {
      print('Error awarding swap completion: $e');
      return [];
    }
  }
}
