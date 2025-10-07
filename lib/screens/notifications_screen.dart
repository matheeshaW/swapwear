import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/notifications_manager.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _clearAllNotifications(String userId) async {
    try {
      // Get all notifications for the user
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();
      
      // Delete all notifications
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('✅ All notifications cleared for user: $userId');
    } catch (e) {
      print('❌ Failed to clear notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications.')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear All Notifications',
            onPressed: () async {
              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Notifications'),
                  content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                await _clearAllNotifications(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications cleared'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Swaps'),
              Tab(text: 'Badges'),
              Tab(text: 'Deliveries'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _NotificationsList(type: 'Swaps'),
            _NotificationsList(type: 'Badges'),
            _NotificationsList(type: 'Deliveries'),
          ],
        ),
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final String type;
  const _NotificationsList({required this.type});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view notifications.'));
    }
    print('NotificationsScreen: User ID: ${user.uid}');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationsManager.instance.streamAllNotifications(
        userId: user.uid,
      ),
      builder: (context, snapshot) {
        print('StreamBuilder for $type: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, docs: ${snapshot.data?.docs.length ?? 0}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snapshot.data?.docs ?? const [];
        final docs = allDocs.where((doc) => doc.data()['type'] == type).toList();
        print('Filtered docs for $type: ${docs.length} out of ${allDocs.length} total');
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No notifications yet'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    print('Adding test notification...');
                    await NotificationsManager.instance.addTestNotification(
                      userId: user.uid,
                      type: type,
                      title: 'Test $type Notification',
                      message: 'This is a test notification for $type',
                      tag: '#Test',
                    );
                    print('Test notification added');
                  },
                  child: Text('Add Test $type Notification'),
                ),
              ],
            ),
          );
        }

        // Group by day (Today / Yesterday / Others)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        final todayItems = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final yesterdayItems = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final olderItems = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (final d in docs) {
          final ts = d.data()['timestamp'];
          DateTime when;
          if (ts is Timestamp) {
            when = ts.toDate();
          } else if (ts is DateTime) {
            when = ts;
          } else {
            when = DateTime.fromMillisecondsSinceEpoch(0);
          }
          final day = DateTime(when.year, when.month, when.day);
          if (day == today) {
            todayItems.add(d);
          } else if (day == yesterday) {
            yesterdayItems.add(d);
          } else {
            olderItems.add(d);
          }
        }

        List<Widget> sections = [];
        void addSection(
          String title,
          List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
        ) {
          if (items.isEmpty) return;
          sections.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
          sections.addAll(items.map((d) => _NotificationTile(doc: d)));
        }

        addSection('Today', todayItems);
        addSection('Yesterday', yesterdayItems);
        addSection('Earlier', olderItems);

        return ListView(children: sections);
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _NotificationTile({required this.doc});

  IconData _iconForType(String type) {
    switch (type) {
      case 'Swaps':
        return Icons.check_circle_outline; // ✅
      case 'Badges':
        return Icons.emoji_events_outlined; // 🏆
      case 'Deliveries':
        return Icons.local_shipping_outlined; // 🚚
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final isRead = data['isRead'] == true;
    final type = (data['type'] as String?) ?? 'Swaps';
    final title = (data['title'] as String?) ?? '';
    final message = (data['message'] as String?) ?? '';
    final tag = (data['tag'] as String?) ?? '';

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(child: Icon(_iconForType(type))),
          if (!isRead)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title.isEmpty ? type : title,
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(tag.isNotEmpty ? '$message  •  $tag' : message),
      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !isRead) {
          await NotificationsManager.instance.markAsRead(
            userId: user.uid,
            id: doc.id,
          );
        }
      },
    );
  }
}
