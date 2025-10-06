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
  late final Stream<List<SwapModel>> _swapsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user!.uid;
    _swapsStream = FirebaseFirestore.instance
        .collection('swaps')
        .where(
          Filter.or(
            Filter('fromUserId', isEqualTo: _uid),
            Filter('toUserId', isEqualTo: _uid),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => SwapModel.fromMap(d.data(), d.id))
              .toList(),
        );
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
        final bool isPending = status == 'pending';
        final bool isAccepted = status == 'accepted';
        final bool isRejected = status == 'rejected';
        final bool isReceiver = _uid == swap.toUserId;

        Color? cardTint;
        if (isAccepted)
          cardTint = Colors.green.withOpacity(0.06);
        else if (isRejected)
          cardTint = Colors.red.withOpacity(0.06);
        else if (isPending)
          cardTint = Colors.amber.withOpacity(0.06);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: cardTint ?? Colors.white,
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
                          const SizedBox(width: 8),
                          if (isPending && !isReceiver)
                            const Text(
                              'Waiting for receiver to accept...',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      if (isAccepted) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Swap Accepted – Start Chat.',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (isRejected) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Swap Rejected.',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isPending && isReceiver)
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await SwapService().updateSwapStatus(
                                swap.id!,
                                'accepted',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await SwapService().updateSwapStatus(
                                swap.id!,
                                'rejected',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
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
          stream: _swapsStream,
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
