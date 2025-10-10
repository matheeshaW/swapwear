import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/swap_model.dart';
import '../services/swap_service.dart';
import 'chat_screen.dart';
import 'track_delivery_page.dart';

class MySwapsScreen extends StatefulWidget {
  const MySwapsScreen({super.key});

  @override
  State<MySwapsScreen> createState() => _MySwapsScreenState();
}

class _MySwapsScreenState extends State<MySwapsScreen> {
  late final String _uid;
  late final Stream<List<SwapModel>> _swapsStream;
  String selectedFilter = 'All';

  final List<String> filters = [
    'All',
    'pending',
    'accepted',
    'confirmed',
    'rejected',
    'completed',
  ];

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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.handshake_outlined;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'completed':
        return Icons.done_all_rounded;
      case 'pending':
        return Icons.access_time_outlined;
      default:
        return Icons.swap_horiz;
    }
  }

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
        'offeredTitle': offered.data()?['title'] ?? 'Unknown',
        'offeredImage': offered.data()?['imageUrl'] ?? '',
        'requestedTitle': requested.data()?['title'] ?? 'Unknown',
        'requestedImage': requested.data()?['imageUrl'] ?? '',
      };
    }

    final status = swap.status;
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    final bool isPending = status == 'pending';
    final bool isAccepted = status == 'accepted';
    final bool isConfirmed = status == 'confirmed';
    final bool isRejected = status == 'rejected';
    final bool isReceiver = _uid == swap.toUserId;
    final createdAtDate = swap.createdAt?.toDate();

    String dateLabel() {
      if (createdAtDate == null) return '';
      final now = DateTime.now();
      final diff = now.difference(createdAtDate);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${createdAtDate.day.toString().padLeft(2, '0')}/${createdAtDate.month.toString().padLeft(2, '0')}/${createdAtDate.year}';
      }
    }

    Widget thumb(String url, bool isOffered) {
      final has = url.isNotEmpty;
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD1FAE5), width: 2),
          image: has
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: has
            ? null
            : Icon(
                isOffered ? Icons.upload_outlined : Icons.download_outlined,
                color: const Color(0xFF10B981),
                size: 28,
              ),
      );
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

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Status Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    if (createdAtDate != null)
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: color.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel(),
                            style: TextStyle(
                              color: color.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Main Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Swap Preview
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: isReceiver
                          ? [
                              // Receiver: YOU OFFER = requested, YOU GET = offered
                              Expanded(
                                child: Column(
                                  children: [
                                    thumb(meta['requestedImage']!, true),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU OFFER',
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      meta['requestedTitle']!,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 20,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.sync_alt_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    thumb(meta['offeredImage']!, false),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU GET',
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      meta['offeredTitle']!,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          : [
                              // Sender: original order
                              Expanded(
                                child: Column(
                                  children: [
                                    thumb(meta['offeredImage']!, true),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU OFFER',
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      meta['offeredTitle']!,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 20,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.sync_alt_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    thumb(meta['requestedImage']!, false),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU GET',
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      meta['requestedTitle']!,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                    ),

                    // Status Messages
                    if (isAccepted) ...[
                      const SizedBox(height: 16),
                      Container(
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
                              color: Color(0xFF065F46),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Negotiating – waiting for confirmation',
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
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.15),
                              const Color(0xFF059669).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.celebration_outlined,
                              color: Color(0xFF065F46),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Swap confirmed! Arrange delivery in chat',
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
                      const SizedBox(height: 16),
                      Container(
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
                              color: Color(0xFF991B1B),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This swap was declined',
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
                    if (isPending && !isReceiver) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCFFAFE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF06B6D4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.hourglass_empty_rounded,
                              color: Color(0xFF164E63),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Waiting for receiver to respond...',
                                style: TextStyle(
                                  color: Color(0xFF164E63),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action Buttons
                    const SizedBox(height: 16),
                    if (isPending && isReceiver)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => SwapService().updateSwapStatus(
                                swap.id!,
                                'accepted',
                              ),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text(
                                'Accept',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => SwapService().updateSwapStatus(
                                swap.id!,
                                'rejected',
                              ),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text(
                                'Reject',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(
                                  color: Color(0xFFEF4444),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
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
                    const SizedBox(height: 8),
                    // Track Delivery Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrackDeliveryPage(swapId: swap.id ?? ''),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Track Delivery',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    final color = label == 'All'
        ? const Color(0xFF10B981)
        : _statusColor(label.toLowerCase());

    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFD1FAE5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != 'All')
              Icon(
                _statusIcon(label.toLowerCase()),
                size: 16,
                color: isSelected ? Colors.white : color,
              ),
            if (label != 'All') const SizedBox(width: 6),
            Text(
              label == 'All'
                  ? label
                  : label[0].toUpperCase() + label.substring(1),
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        title: Row(
          children: const [
            Icon(Icons.recycling_outlined, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 10),
            Text(
              'My Swaps',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
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
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: filters.map(_buildFilterChip).toList()),
            ),
          ),

          // Swap Count Badge
          StreamBuilder<List<SwapModel>>(
            stream: _swapsStream,
            builder: (context, snapshot) {
              final allSwaps = snapshot.data ?? [];
              final filtered = selectedFilter == 'All'
                  ? allSwaps
                  : allSwaps
                        .where((s) => s.status == selectedFilter.toLowerCase())
                        .toList();

              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD1FAE5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 16,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'swap' : 'swaps'}',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: StreamBuilder<List<SwapModel>>(
              stream: _swapsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  );
                }
                final allSwaps = snapshot.data ?? [];
                final filtered = selectedFilter == 'All'
                    ? allSwaps
                    : allSwaps
                          .where(
                            (s) => s.status == selectedFilter.toLowerCase(),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No swaps found',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedFilter == 'All'
                              ? 'Start swapping to see your exchanges'
                              : 'No $selectedFilter swaps yet',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _buildCompactSwapCard(context, filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
