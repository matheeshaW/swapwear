import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get total swaps count
  Future<int> getTotalSwaps() async {
    try {
      final snapshot = await _db.collection('swaps').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting total swaps: $e');
      return 0;
    }
  }

  // Get active users count (users who made swaps in last 30 days)
  Future<int> getActiveUsers() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _db
          .collection('swaps')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final userIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        userIds.add(data['fromUserId'] as String);
        userIds.add(data['toUserId'] as String);
      }

      return userIds.length;
    } catch (e) {
      print('Error getting active users: $e');
      return 0;
    }
  }

  // Get swap activity for last 7 days
  Future<List<Map<String, dynamic>>> getSwapActivityLast7Days() async {
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> activity = [];

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final snapshot = await _db
            .collection('swaps')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
            .get();

        activity.add({
          'date': startOfDay,
          'count': snapshot.docs.length,
          'dayName': _getDayName(startOfDay.weekday),
        });
      }

      return activity;
    } catch (e) {
      print('Error getting swap activity: $e');
      return List.generate(
        7,
        (index) => {
          'date': DateTime.now().subtract(Duration(days: 6 - index)),
          'count': 0,
          'dayName': _getDayName(
            DateTime.now().subtract(Duration(days: 6 - index)).weekday,
          ),
        },
      );
    }
  }

  // Get environmental impact metrics
  Future<Map<String, double>> getEnvironmentalImpact() async {
    try {
      // Get all user stats
      final snapshot = await _db.collection('userStats').get();

      double totalTextileWastePrevented = 0;
      double totalWaterSaved = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final totalSwaps = (data['totalSwaps'] as num?)?.toDouble() ?? 0;

        // Calculate based on total swaps
        // 0.5 kg textile waste prevented per swap
        totalTextileWastePrevented += totalSwaps * 0.5;

        // 20 liters water saved per swap
        totalWaterSaved += totalSwaps * 20;
      }

      return {
        'textileWastePrevented': totalTextileWastePrevented,
        'waterSaved': totalWaterSaved,
      };
    } catch (e) {
      print('Error getting environmental impact: $e');
      return {'textileWastePrevented': 0.0, 'waterSaved': 0.0};
    }
  }

  // Stream for real-time updates
  Stream<Map<String, dynamic>> getEcoImpactSummary() {
    return _db.collection('swaps').snapshots().asyncMap((_) async {
      final totalSwaps = await getTotalSwaps();
      final activeUsers = await getActiveUsers();
      final swapActivity = await getSwapActivityLast7Days();
      final environmentalImpact = await getEnvironmentalImpact();

      return {
        'totalSwaps': totalSwaps,
        'activeUsers': activeUsers,
        'swapActivity': swapActivity,
        'environmentalImpact': environmentalImpact,
        'lastUpdated': DateTime.now(),
      };
    });
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}
