import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
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
        actions: [
          // Clear All button
          IconButton(
            onPressed: () => _showClearAllDialog(user.uid),
            icon: const Icon(Icons.clear_all, color: Color(0xFFEF4444)),
            tooltip: 'Clear All Notifications',
          ),
          StreamBuilder<int>(
            stream: _notificationService.streamUnreadCount(user.uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount > 0) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _notificationService.markAllAsRead(user.uid),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Mark All Read'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF10B981),
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Swaps'),
                Tab(text: 'Badges'),
                Tab(text: 'Deliveries'),
                Tab(text: 'Other'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllNotificationsList(user.uid),
                _buildNotificationList(user.uid, 'Swaps'),
                _buildNotificationList(user.uid, 'Badges'),
                _buildNotificationList(user.uid, 'Deliveries'),
                _buildOtherNotificationsList(user.uid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllNotificationsList(String userId) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.streamUserNotifications(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('All');
        }

        final notifications = snapshot.data!;
        final groupedNotifications = _groupNotificationsByTime(notifications);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedNotifications.length,
          itemBuilder: (context, index) {
            final group = groupedNotifications[index];
            return _buildNotificationGroup(
              group['timeGroup'] as String,
              group['notifications'] as List<NotificationModel>,
            );
          },
        );
      },
    );
  }

  Widget _buildOtherNotificationsList(String userId) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.streamUserNotifications(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('Other');
        }

        // Filter notifications for other types (Listings, Wishlist, Login, System)
        final allNotifications = snapshot.data!;
        final notifications = allNotifications
            .where(
              (n) =>
                  ['Listings', 'Wishlist', 'Login', 'System'].contains(n.type),
            )
            .toList();

        if (notifications.isEmpty) {
          return _buildEmptyState('Other');
        }

        final groupedNotifications = _groupNotificationsByTime(notifications);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedNotifications.length,
          itemBuilder: (context, index) {
            final group = groupedNotifications[index];
            return _buildNotificationGroup(
              group['timeGroup'] as String,
              group['notifications'] as List<NotificationModel>,
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationList(String userId, String type) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.streamUserNotifications(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(type);
        }

        // Filter notifications by type
        final allNotifications = snapshot.data!;
        final notifications = allNotifications
            .where((n) => n.type == type)
            .toList();

        if (notifications.isEmpty) {
          return _buildEmptyState(type);
        }

        final groupedNotifications = _groupNotificationsByTime(notifications);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedNotifications.length,
          itemBuilder: (context, index) {
            final group = groupedNotifications[index];
            return _buildNotificationGroup(
              group['timeGroup'] as String,
              group['notifications'] as List<NotificationModel>,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String type) {
    String message;
    String icon;

    switch (type) {
      case 'All':
        message = 'No notifications yet';
        icon = '🔔';
        break;
      case 'Swaps':
        message = 'No swap notifications yet';
        icon = '✅';
        break;
      case 'Badges':
        message = 'No badge notifications yet';
        icon = '🏆';
        break;
      case 'Deliveries':
        message = 'No delivery notifications yet';
        icon = '🚚';
        break;
      case 'Other':
        message = 'No other notifications yet';
        icon = '📋';
        break;
      default:
        message = 'No notifications yet';
        icon = '🔔';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see notifications here when they arrive',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationGroup(
    String timeGroup,
    List<NotificationModel> notifications,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            timeGroup,
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...notifications.map(
          (notification) => _buildNotificationCard(notification),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: notification.isRead
            ? null
            : Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNotificationTap(notification),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getTypeColor(notification.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      notification.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (notification.tag != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(
                                  notification.type,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                notification.tag!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getTypeColor(notification.type),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            notification.formattedTime,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Swaps':
        return const Color(0xFF10B981);
      case 'Badges':
        return const Color(0xFFF59E0B);
      case 'Deliveries':
        return const Color(0xFF3B82F6);
      case 'Listings':
        return const Color(0xFF8B5CF6);
      case 'Wishlist':
        return const Color(0xFFEC4899);
      case 'Login':
        return const Color(0xFF06B6D4);
      case 'System':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _notificationService.markAsRead(user.uid, notification.id!);
      }
    }
  }

  Future<void> _showClearAllDialog(String userId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 12),
              Text('Clear All Notifications'),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await _notificationService.clearAllNotifications(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications cleared successfully!'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing notifications: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _groupNotificationsByTime(
    List<NotificationModel> notifications,
  ) {
    final Map<String, List<NotificationModel>> grouped = {};

    for (final notification in notifications) {
      final timeGroup = notification.timeGroup;
      if (!grouped.containsKey(timeGroup)) {
        grouped[timeGroup] = [];
      }
      grouped[timeGroup]!.add(notification);
    }

    // Sort time groups: Today, Yesterday, Older
    final orderedGroups = ['Today', 'Yesterday', 'Older'];
    final result = <Map<String, dynamic>>[];

    for (final group in orderedGroups) {
      if (grouped.containsKey(group)) {
        result.add({'timeGroup': group, 'notifications': grouped[group]!});
      }
    }

    return result;
  }
}
