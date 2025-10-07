import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/swap_model.dart';
import '../models/delivery_model.dart';
import '../services/swap_service.dart';
import '../services/delivery_service.dart';
import 'chat_screen.dart';
import 'track_delivery_screen.dart';
import 'delivery_location_screen.dart';

class MySwapsScreen extends StatefulWidget {
  const MySwapsScreen({super.key});

  @override
  State<MySwapsScreen> createState() => _MySwapsScreenState();
}

class _MySwapsScreenState extends State<MySwapsScreen> {
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
        return const Color(0xFF14B8A6); // Teal
      case 'confirmed':
        return const Color(0xFF10B981); // Emerald
      case 'rejected':
        return const Color(0xFFEF4444); // Red
      case 'completed':
        return const Color(0xFF6B7280); // Gray
      case 'pending':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Compact card with thumbnails, titles, status chip, and date, preserving actions
  Widget _buildCompactSwapCard(BuildContext context, SwapModel swap) {
    Future<Map<String, dynamic>> loadListingMeta() async {
      final db = FirebaseFirestore.instance;
      final offered = await db
          .collection('listings')
          .doc(swap.listingOfferedId)
          .get();
      final requested = await db
          .collection('listings')
          .doc(swap.listingRequestedId)
          .get();
      return {
        'offeredTitle': offered.data()?['title']?.toString() ?? 'Unknown',
        'offeredImage': (offered.data()?['imageUrl']?.toString() ?? ''),
        'requestedTitle': requested.data()?['title']?.toString() ?? 'Unknown',
        'requestedImage': (requested.data()?['imageUrl']?.toString() ?? ''),
      };
    }

    final status = swap.status;
    final color = _statusColor(status);
    final bool isPending = status == 'pending';
    final bool isAccepted = status == 'accepted';
    final bool isRejected = status == 'rejected';
    final bool isConfirmed = status == 'confirmed';
    final bool isReceiver = _uid == swap.toUserId;
    final createdAtDate = swap.createdAt?.toDate();

    Widget statusChip() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    String dateLabel() {
      if (createdAtDate == null) return '';
      return '${createdAtDate.day.toString().padLeft(2, '0')}/${createdAtDate.month.toString().padLeft(2, '0')}/${createdAtDate.year}';
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: loadListingMeta(),
      builder: (context, snap) {
        final meta =
            snap.data ??
            const {
              'offeredTitle': '...',
              'offeredImage': '',
              'requestedTitle': '...',
              'requestedImage': '',
            };

        Widget thumb(String url) {
          final has = url.isNotEmpty;
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1FAE5)),
              image: has
                  ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                  : null,
            ),
            child: has
                ? null
                : const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  thumb(meta['offeredImage'] as String),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta['offeredTitle'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.sync_alt_rounded,
                              size: 18,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                meta['requestedTitle'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  statusChip(),
                  const Spacer(),
                  if (createdAtDate != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateLabel(),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isPending && isReceiver)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await SwapService().updateSwapStatus(
                            swap.id!,
                            'accepted',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await SwapService().updateSwapStatus(
                            swap.id!,
                            'rejected',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text(
                          'Open Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (isConfirmed) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: StreamBuilder<DeliveryModel?>(
                          stream: DeliveryService().streamDeliveryBySwapId(
                            swap.id!,
                          ),
                          builder: (context, deliverySnapshot) {
                            final delivery = deliverySnapshot.data;
                            final hasDelivery = delivery != null;

                            return ElevatedButton.icon(
                              onPressed: () async {
                                if (hasDelivery) {
                                  // Navigate to tracking screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TrackDeliveryScreen(
                                        deliveryId: delivery.id!,
                                        swapId: swap.id!,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Navigate to delivery location screen
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DeliveryLocationScreen(
                                        swapId: swap.id!,
                                        itemName: 'Swap Item',
                                        fromUserId: swap.fromUserId,
                                        toUserId: swap.toUserId,
                                      ),
                                    ),
                                  );

                                  // If delivery was created successfully, show success message
                                  if (result == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Delivery location saved successfully!',
                                        ),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: Icon(
                                hasDelivery
                                    ? Icons.local_shipping_outlined
                                    : Icons.location_on_outlined,
                                size: 18,
                              ),
                              label: Text(
                                hasDelivery ? 'Track Delivery' : 'Delivery',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasDelivery
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),

              if (isAccepted) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF7EC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Negotiation in progress – waiting for final confirmation',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (isConfirmed) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF7EC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.celebration_outlined,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Swap confirmed! Discuss delivery details in chat',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (isRejected) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This swap request was declined',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // removed unused _statusIcon (compact card uses chip-style only)

  // removed legacy _buildSwapCard (replaced by _buildCompactSwapCard)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        title: const Text(
          'My Swaps',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<SwapModel>>(
        stream: _swapsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }
          final swaps = snapshot.data ?? const <SwapModel>[];

          final pending = swaps.where((s) => s.status == 'pending').toList();
          final accepted = swaps.where((s) => s.status == 'accepted').toList();
          final confirmed = swaps
              .where((s) => s.status == 'confirmed')
              .toList();
          final rejected = swaps.where((s) => s.status == 'rejected').toList();
          final completed = swaps
              .where((s) => s.status == 'completed')
              .toList();

          if (swaps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 64,
                    color: Color(0xFFD1FAE5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No swaps yet',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your swaps will appear here',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          List<Widget> sections = [];

          Widget sectionHeader(String label, int count) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          void addSection(String label, List<SwapModel> list) {
            if (list.isEmpty) return;
            sections.add(sectionHeader(label, list.length));
            for (final s in list) {
              sections.add(_buildCompactSwapCard(context, s));
            }
          }

          addSection('🕒 Pending Requests', pending);
          addSection('🤝 Accepted Swaps', accepted);
          addSection('✅ Confirmed Swaps', confirmed);
          addSection('❌ Rejected Swaps', rejected);
          addSection('🏁 Completed Swaps', completed);

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections,
            ),
          );
        },
      ),
    );
  }
}
