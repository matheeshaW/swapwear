import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_stats_model.dart';
import '../models/leaderboard_model.dart';
import '../services/achievements_service.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage>
    with TickerProviderStateMixin {
  final AchievementsService _achievementsService = AchievementsService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _filter = 'All time';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view achievements')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        title: const Text(
          'Achievements',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFFD1FAE5),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Stats Section
              _buildUserStatsSection(user.uid),
              const SizedBox(height: 24),

              // Badges Section
              _buildBadgesSection(user.uid),
              const SizedBox(height: 24),

              // Leaderboard Section
              _buildLeaderboardSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserStatsSection(String userId) {
    return StreamBuilder<UserStatsModel?>(
      stream: _achievementsService.streamUserStats(userId),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return _buildUserStatsCard(
            username: 'Loading...',
            ecoPoints: 0,
            totalSwaps: 0,
            isLoading: true,
          );
        }

        final userStats = statsSnapshot.data;
        final ecoPoints = userStats?.ecoPoints ?? 0;
        final totalSwaps = userStats?.totalSwaps ?? 0;

        // Get username from user profile
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, userSnapshot) {
            String username = 'User';
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data();
              final name = userData?['name'] as String?;
              if (name != null && name.isNotEmpty) {
                username = '@$name';
              } else {
                username = '@user_${userId.substring(0, 8)}';
              }
            }

            return _buildUserStatsCard(
              username: username,
              ecoPoints: ecoPoints,
              totalSwaps: totalSwaps,
              isLoading: false,
            );
          },
        );
      },
    );
  }

  Widget _buildUserStatsCard({
    required String username,
    required int ecoPoints,
    required int totalSwaps,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Avatar and Username
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                child: const Icon(
                  Icons.person,
                  size: 30,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Eco Warrior',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.eco,
                  label: 'Eco Points',
                  value: ecoPoints.toString(),
                  color: const Color(0xFF10B981),
                  isLoading: isLoading,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.swap_horiz,
                  label: 'Total Swaps',
                  value: totalSwaps.toString(),
                  color: const Color(0xFF3B82F6),
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isLoading ? '...' : value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Badges',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<UserStatsModel?>(
          stream: _achievementsService.streamUserStats(userId),
          builder: (context, snapshot) {
            final userStats = snapshot.data;
            final earnedBadges = userStats?.badges ?? [];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: AchievementsService.badgeDefinitions.length,
              itemBuilder: (context, index) {
                final badgeEntry = AchievementsService.badgeDefinitions.entries
                    .elementAt(index);
                final badgeId = badgeEntry.key;
                final badge = badgeEntry.value;
                final isEarned = earnedBadges.contains(badgeId);

                return _buildBadgeCard(
                  icon: badge['icon'] as String,
                  name: badge['name'] as String,
                  description: badge['description'] as String,
                  isEarned: isEarned,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBadgeCard({
    required String icon,
    required String name,
    required String description,
    required bool isEarned,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEarned ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEarned ? const Color(0xFF10B981) : Colors.grey[300]!,
          width: isEarned ? 2 : 1,
        ),
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: TextStyle(
              fontSize: 32,
              color: isEarned ? const Color(0xFF10B981) : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isEarned ? const Color(0xFF0F172A) : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: isEarned ? Colors.grey[600] : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Eco Warriors',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            // Filter dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<String>(
                value: _filter,
                underline: const SizedBox(),
                items: ['All time', 'This month'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _filter = newValue;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<LeaderboardModel>>(
          stream: _achievementsService.streamLeaderboard(limit: 10),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLeaderboardLoading();
            }

            final leaderboard = snapshot.data ?? [];
            if (leaderboard.isEmpty) {
              return _buildEmptyLeaderboard();
            }

            return _buildLeaderboardList(leaderboard);
          },
        ),
      ],
    );
  }

  Widget _buildLeaderboardLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      ),
    );
  }

  Widget _buildEmptyLeaderboard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No leaderboard data yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardModel> leaderboard) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: leaderboard.length,
        itemBuilder: (context, index) {
          final user = leaderboard[index];
          final rank = index + 1;

          return _buildLeaderboardItem(user, rank);
        },
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardModel user, int rank) {
    String rankIcon = '';
    Color rankColor = Colors.grey[600]!;

    if (rank == 1) {
      rankIcon = '🥇';
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankIcon = '🥈';
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankIcon = '🥉';
      rankColor = const Color(0xFFCD7F32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                rankIcon.isNotEmpty ? rankIcon : rank.toString(),
                style: TextStyle(
                  fontSize: rankIcon.isNotEmpty ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Text(
              user.username,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          // Eco Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${user.ecoPoints} pts',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
