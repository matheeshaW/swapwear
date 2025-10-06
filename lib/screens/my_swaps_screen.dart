import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/swap_model.dart';
import '../services/swap_service.dart';
import 'chat_screen.dart';

class MySwapsScreen extends StatefulWidget {
  const MySwapsScreen({super.key});

  @override
  State<MySwapsScreen> createState() => _MySwapsScreenState();
}

class _MySwapsScreenState extends State<MySwapsScreen>
    with SingleTickerProviderStateMixin {
  late final String _uid;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user!.uid;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.grey;
      case 'pending':
      default:
        return Colors.blue;
    }
  }

  Widget _buildSwapCard(BuildContext context, SwapModel swap) {
    Future<List<String>> loadTitles() async {
      final db = FirebaseFirestore.instance;
      final offeredSnap = await db
          .collection('listings')
          .doc(swap.listingOfferedId)
          .get();
      final requestedSnap = await db
          .collection('listings')
          .doc(swap.listingRequestedId)
          .get();
      final offeredTitle =
          offeredSnap.data()?['title']?.toString() ?? 'Unknown';
      final requestedTitle =
          requestedSnap.data()?['title']?.toString() ?? 'Unknown';
      return <String>[offeredTitle, requestedTitle];
    }

    return FutureBuilder<List<String>>(
      future: loadTitles(),
      builder: (context, snap) {
        final titles = snap.data ?? const ['...', '...'];
        final status = swap.status;
        final color = _statusColor(status);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.swap_horiz, color: Colors.black54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${titles[0]}  ↔  ${titles[1]}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: swap.chatId,
                          currentUserId: _uid,
                          swapId: swap.id,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Open Chat'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('My Swaps'),
          bottom: const TabBar(
            labelColor: Color(0xFF667eea),
            unselectedLabelColor: Colors.black54,
            indicatorColor: Color(0xFF667eea),
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: StreamBuilder<List<SwapModel>>(
          stream: SwapService().getUserSwaps(_uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final swaps = snapshot.data ?? const <SwapModel>[];
            final active = swaps
                .where((s) => s.status == 'pending' || s.status == 'accepted')
                .toList();
            final past = swaps
                .where((s) => s.status == 'rejected' || s.status == 'completed')
                .toList();

            Widget buildList(List<SwapModel> list) {
              if (list.isEmpty) {
                return const Center(child: Text('No swaps'));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final swap = list[index];
                  return _buildSwapCard(context, swap);
                },
              );
            }

            return TabBarView(children: [buildList(active), buildList(past)]);
          },
        ),
      ),
    );
  }
}
