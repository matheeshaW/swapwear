import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/swap_service.dart';

class ListingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String listingId;
  final String userId;

  const ListingDetailsScreen({
    super.key,
    required this.data,
    required this.listingId,
    required this.userId,
  });

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  String? _selectedOfferedId;
  bool _isSubmitting = false;

  Future<List<Map<String, dynamic>>> fetchUserListings(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('listings')
        .where('userId', isEqualTo: userId)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<String?> showOfferedListingPicker(
    BuildContext context,
    List<Map<String, dynamic>> userListings,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Your Listing to Offer'),
          children: userListings.map((listing) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, listing['id'] as String),
              child: Text(listing['title'] ?? 'Untitled'),
            );
          }).toList(),
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _swapStream({
    required String fromUserId,
    required String toUserId,
    required String listingOfferedId,
    required String listingRequestedId,
  }) {
    return FirebaseFirestore.instance
        .collection('swaps')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('listingOfferedId', isEqualTo: listingOfferedId)
        .where('listingRequestedId', isEqualTo: listingRequestedId)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _swapStreamAnyOffered({
    required String fromUserId,
    required String toUserId,
    required String listingRequestedId,
  }) {
    return FirebaseFirestore.instance
        .collection('swaps')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('listingRequestedId', isEqualTo: listingRequestedId)
        .limit(1)
        .snapshots();
  }

  Future<void> _handleRequestSwap(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }
    if (widget.userId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot swap your own listing.')),
      );
      return;
    }

    final userListings = await fetchUserListings(currentUser.uid);
    if (userListings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no listings to offer!')),
      );
      return;
    }

    // If not selected yet, ask user to pick
    final offeredId =
        _selectedOfferedId ??
        await showOfferedListingPicker(context, userListings);
    if (offeredId == null) return;

    setState(() {
      _selectedOfferedId = offeredId;
      _isSubmitting = true;
    });

    try {
      // Prevent duplicate or finalized request regardless of offered item
      final existingPending = await FirebaseFirestore.instance
          .collection('swaps')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: widget.userId)
          .where('listingRequestedId', isEqualTo: widget.listingId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existingPending.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A pending request already exists.')),
        );
        return;
      }

      final existingAcceptedOrCompleted = await FirebaseFirestore.instance
          .collection('swaps')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: widget.userId)
          .where('listingRequestedId', isEqualTo: widget.listingId)
          .where('status', whereIn: ['accepted', 'completed'])
          .limit(1)
          .get();
      if (existingAcceptedOrCompleted.docs.isNotEmpty) {
        final status =
            existingAcceptedOrCompleted.docs.first.data()['status'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Swap is already ${status ?? 'active'}.')),
        );
        return;
      }

      await SwapService().createSwapRequest(
        fromUserId: currentUser.uid,
        toUserId: widget.userId,
        listingOfferedId: offeredId,
        listingRequestedId: widget.listingId,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Swap request sent!')));
      // Optional enhancement: could navigate to chat using created chatId (swapRef.id)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send swap request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listing Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.data['imageUrl'],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 220,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 220,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.data['title'] ?? '',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text('Size: ${widget.data['size'] ?? '-'}'),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('Condition: ${widget.data['condition'] ?? '-'}'),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((widget.data['category'] ?? '') is String &&
                    (widget.data['category'] ?? '').isNotEmpty)
                  Chip(
                    label: Text('Category: ${widget.data['category']}'),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  ),
                ...((widget.data['tags'] is List)
                        ? (widget.data['tags'] as List).cast<dynamic>()
                        : <dynamic>[])
                    .map(
                      (t) => Chip(
                        label: Text(t.toString()),
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.data['description'] != null)
              Text(
                widget.data['description'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: _buildSwapButton(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapButton(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return ElevatedButton(
        onPressed: null,
        child: const Text('Login to Request Swap'),
      );
    }
    if (widget.userId == currentUser.uid) {
      return ElevatedButton(
        onPressed: null,
        child: const Text('This is your listing'),
      );
    }

    if (_selectedOfferedId == null) {
      // Respect existing swaps for this listing even before selecting an offered item
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _swapStreamAnyOffered(
          fromUserId: currentUser.uid,
          toUserId: widget.userId,
          listingRequestedId: widget.listingId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ElevatedButton(
              onPressed: null,
              child: const Text('Loading…'),
            );
          }

          String? status;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final data = snapshot.data!.docs.first.data();
            status = data['status'] as String?;
          }

          String label;
          bool enabled;
          VoidCallback? onPressed;

          if (status == null) {
            label = _isSubmitting ? 'Loading…' : 'Request Swap';
            enabled = !_isSubmitting;
            onPressed = _isSubmitting
                ? null
                : () => _handleRequestSwap(context);
          } else if (status == 'pending') {
            label = 'Request Sent ✅';
            enabled = false;
          } else if (status == 'accepted') {
            label = 'Swap Accepted';
            enabled = false;
          } else if (status == 'completed') {
            label = 'Swap Completed';
            enabled = false;
          } else if (status == 'rejected') {
            label = _isSubmitting ? 'Loading…' : 'Request Swap Again';
            enabled = !_isSubmitting;
            onPressed = _isSubmitting
                ? null
                : () => _handleRequestSwap(context);
          } else {
            label = 'Request Swap';
            enabled = !_isSubmitting;
            onPressed = _isSubmitting
                ? null
                : () => _handleRequestSwap(context);
          }

          return ElevatedButton(
            onPressed: enabled ? onPressed : null,
            child: Text(label),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _swapStream(
        fromUserId: currentUser.uid,
        toUserId: widget.userId,
        listingOfferedId: _selectedOfferedId!,
        listingRequestedId: widget.listingId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ElevatedButton(onPressed: null, child: const Text('Loading…'));
        }

        String? status;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          final data = doc.data();
          status = data['status'] as String?;
        }

        // Determine label and enabled state
        String label;
        bool enabled;
        VoidCallback? onPressed;

        if (status == null) {
          label = _isSubmitting ? 'Loading…' : 'Request Swap';
          enabled = !_isSubmitting;
          onPressed = _isSubmitting ? null : () => _handleRequestSwap(context);
        } else if (status == 'pending') {
          label = 'Request Sent ✅';
          enabled = false;
        } else if (status == 'accepted') {
          label = 'Swap Accepted';
          enabled = false;
          // Optional: open chat using swapId as chatId if desired
        } else if (status == 'rejected') {
          label = _isSubmitting ? 'Loading…' : 'Request Swap Again';
          enabled = !_isSubmitting;
          onPressed = _isSubmitting ? null : () => _handleRequestSwap(context);
        } else if (status == 'completed') {
          label = 'Swap Completed';
          enabled = false;
        } else {
          label = 'Request Swap';
          enabled = !_isSubmitting;
          onPressed = _isSubmitting ? null : () => _handleRequestSwap(context);
        }

        return ElevatedButton(
          onPressed: enabled ? onPressed : null,
          child: Text(label),
        );
      },
    );
  }
}
