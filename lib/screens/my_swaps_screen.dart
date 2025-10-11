import 'package:cached_network_image/cached_network_image.dart';
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

  // Cache for listing metadata to avoid repeated Firestore calls
  final Map<String, Map<String, dynamic>> _listingCache = {};

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

    // Stream all swaps where current user is either sender or receiver
    // and hasn't deleted the swap
    _swapsStream = FirebaseFirestore.instance
        .collection('swaps')
        .where(
          Filter.or(
            Filter('fromUserId', isEqualTo: _uid),
            Filter('toUserId', isEqualTo: _uid),
          ),
        )
        .snapshots()
        .map((snapshot) {
          final swaps = snapshot.docs
              .map((d) => SwapModel.fromMap(d.data(), d.id))
              .where((swap) {
                // Filter out swaps that current user has deleted
                final deletedBy = (swap.deletedBy as List<dynamic>?) ?? [];
                return !deletedBy.contains(_uid);
              })
              .toList();
          // Sort in memory instead of using Firestore orderBy
          swaps.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });
          return swaps;
        });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF14B8A6);
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF6B7280);
      case 'pending':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  Widget _buildItemColumn({
    required String imageUrl,
    required String title,
    required String label,
    required bool isOffered,
  }) {
    return Expanded(
      child: Column(
        children: [
          _buildItemThumbnail(imageUrl, isOffered),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF059669),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
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
    );
  }

  Widget _buildItemThumbnail(String url, bool isOffered) {
    final hasImage = url.isNotEmpty;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: url,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  isOffered ? Icons.upload_outlined : Icons.download_outlined,
                  color: const Color(0xFFEF4444),
                  size: 28,
                ),
                memCacheWidth: 128,
                memCacheHeight: 128,
                maxWidthDiskCache: 256,
                maxHeightDiskCache: 256,
              )
            : Icon(
                isOffered ? Icons.upload_outlined : Icons.download_outlined,
                color: const Color(0xFF10B981),
                size: 28,
              ),
      ),
    );
  }

  Widget _buildSwapIcon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
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
    );
  }

  Widget _buildStatusMessage(String status, bool isReceiver) {
    final bool isAccepted = status == 'accepted';
    final bool isConfirmed = status == 'confirmed';
    final bool isRejected = status == 'rejected';
    final bool isPending = status == 'pending';

    Widget? messageWidget;

    if (isAccepted) {
      messageWidget = _buildInfoBox(
        icon: Icons.info_outline,
        message: 'Negotiating – waiting for confirmation',
        backgroundColor: const Color(0xFFDEF7EC),
        borderColor: const Color(0xFF10B981),
        textColor: const Color(0xFF065F46),
      );
    } else if (isConfirmed) {
      messageWidget = _buildInfoBox(
        icon: Icons.celebration_outlined,
        message: 'Swap confirmed! Arrange delivery in chat',
        backgroundColor: const Color(0xFFDEF7EC),
        borderColor: const Color(0xFF10B981),
        textColor: const Color(0xFF065F46),
        useGradient: true,
      );
    } else if (isRejected) {
      messageWidget = _buildInfoBox(
        icon: Icons.error_outline,
        message: 'This swap was declined',
        backgroundColor: const Color(0xFFFEE2E2),
        borderColor: const Color(0xFFEF4444),
        textColor: const Color(0xFF991B1B),
      );
    } else if (isPending && !isReceiver) {
      messageWidget = _buildInfoBox(
        icon: Icons.hourglass_empty_rounded,
        message: 'Waiting for receiver to respond...',
        backgroundColor: const Color(0xFFCFFAFE),
        borderColor: const Color(0xFF06B6D4),
        textColor: const Color(0xFF164E63),
      );
    }

    return messageWidget != null
        ? Padding(padding: const EdgeInsets.only(top: 16), child: messageWidget)
        : const SizedBox.shrink();
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String message,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    bool useGradient = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: useGradient ? null : backgroundColor,
        gradient: useGradient
            ? LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.15),
                  const Color(0xFF059669).withOpacity(0.1),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: useGradient ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSwap(BuildContext context, String swapId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 12),
            Text(
              'Remove Swap?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will remove this swap from your history. The other user will still be able to see it.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Add current user to deletedBy array (soft delete)
        await FirebaseFirestore.instance.collection('swaps').doc(swapId).update(
          {
            'deletedBy': FieldValue.arrayUnion([_uid]),
          },
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Swap removed from your history'),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Optional: Check if both users have deleted, then permanently delete
        final swapDoc = await FirebaseFirestore.instance
            .collection('swaps')
            .doc(swapId)
            .get();

        if (swapDoc.exists) {
          final data = swapDoc.data();
          final deletedBy = (data?['deletedBy'] as List<dynamic>?) ?? [];
          final fromUserId = data?['fromUserId'];
          final toUserId = data?['toUserId'];

          // If both users have deleted, permanently remove the document
          if (deletedBy.length == 2 &&
              deletedBy.contains(fromUserId) &&
              deletedBy.contains(toUserId)) {
            await FirebaseFirestore.instance
                .collection('swaps')
                .doc(swapId)
                .delete();
            debugPrint('Both users deleted swap - permanently removed');
          }
        }
      } catch (e) {
        debugPrint('Error deleting swap: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Failed to remove: ${e.toString()}')),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Widget _buildCompactSwapCard(BuildContext context, SwapModel swap) {
    Future<Map<String, dynamic>> loadListingMeta() async {
      try {
        final db = FirebaseFirestore.instance;

        // Check cache first
        final offeredCacheKey = swap.listingOfferedId;
        final requestedCacheKey = swap.listingRequestedId;

        Map<String, dynamic>? offeredData;
        Map<String, dynamic>? requestedData;

        // Load offered listing (with cache)
        if (_listingCache.containsKey(offeredCacheKey)) {
          offeredData = _listingCache[offeredCacheKey];
        } else {
          final offeredDoc = await db
              .collection('listings')
              .doc(offeredCacheKey)
              .get();
          offeredData = offeredDoc.data();
          if (offeredData != null) {
            _listingCache[offeredCacheKey] = offeredData;
          }
        }

        // Load requested listing (with cache)
        if (_listingCache.containsKey(requestedCacheKey)) {
          requestedData = _listingCache[requestedCacheKey];
        } else {
          final requestedDoc = await db
              .collection('listings')
              .doc(requestedCacheKey)
              .get();
          requestedData = requestedDoc.data();
          if (requestedData != null) {
            _listingCache[requestedCacheKey] = requestedData;
          }
        }

        return {
          'offeredTitle': offeredData?['title'] ?? 'Unknown',
          'offeredImage': offeredData?['imageUrl'] ?? '',
          'requestedTitle': requestedData?['title'] ?? 'Unknown',
          'requestedImage': requestedData?['imageUrl'] ?? '',
        };
      } catch (e) {
        debugPrint('Error loading listing meta: $e');
        return {
          'offeredTitle': 'Error loading',
          'offeredImage': '',
          'requestedTitle': 'Error loading',
          'requestedImage': '',
        };
      }
    }

    final status = swap.status;
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    final bool isPending = status == 'pending';
    final bool isReceiver = _uid == swap.toUserId;
    final bool canDelete = status == 'rejected' || status == 'completed';

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
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: color.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(swap.createdAt),
                          style: TextStyle(
                            color: color.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Delete button for rejected/completed swaps
                    if (canDelete) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _deleteSwap(context, swap.id!),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Main Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Swap Preview - Logic fixed for receiver vs sender
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: isReceiver
                          ? [
                              // Receiver view: YOU OFFER = requested item, YOU GET = offered item
                              _buildItemColumn(
                                imageUrl: meta['requestedImage']!,
                                title: meta['requestedTitle']!,
                                label: 'YOU OFFER',
                                isOffered: true,
                              ),
                              _buildSwapIcon(),
                              _buildItemColumn(
                                imageUrl: meta['offeredImage']!,
                                title: meta['offeredTitle']!,
                                label: 'YOU GET',
                                isOffered: false,
                              ),
                            ]
                          : [
                              // Sender view: YOU OFFER = offered item, YOU GET = requested item
                              _buildItemColumn(
                                imageUrl: meta['offeredImage']!,
                                title: meta['offeredTitle']!,
                                label: 'YOU OFFER',
                                isOffered: true,
                              ),
                              _buildSwapIcon(),
                              _buildItemColumn(
                                imageUrl: meta['requestedImage']!,
                                title: meta['requestedTitle']!,
                                label: 'YOU GET',
                                isOffered: false,
                              ),
                            ],
                    ),

                    // Status Messages
                    _buildStatusMessage(status, isReceiver),

                    // Action Buttons
                    const SizedBox(height: 16),
                    if (isPending && isReceiver)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await SwapService().updateSwapStatus(
                                    swap.id!,
                                    'accepted',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Swap accepted!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
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
                              onPressed: () async {
                                try {
                                  await SwapService().updateSwapStatus(
                                    swap.id!,
                                    'rejected',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Swap rejected'),
                                        backgroundColor: Color(0xFFEF4444),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
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
                        .where(
                          (s) =>
                              s.status.toLowerCase() ==
                              selectedFilter.toLowerCase(),
                        )
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

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading swaps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final allSwaps = snapshot.data ?? [];
                final filtered = selectedFilter == 'All'
                    ? allSwaps
                    : allSwaps
                          .where(
                            (s) =>
                                s.status.toLowerCase() ==
                                selectedFilter.toLowerCase(),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
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
