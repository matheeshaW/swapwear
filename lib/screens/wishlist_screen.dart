import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';
import 'listing_details_screen.dart';

class WishlistScreen extends StatefulWidget {
  final String userId;
  const WishlistScreen({super.key, required this.userId});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  // No alert-related state — wishlist screen shows user's wishlist items only
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _wishlistSub;

  @override
  void initState() {
    super.initState();
    // nothing extra to initialize for alerts
  }

  @override
  void dispose() {
    _wishlistSub?.cancel();
    super.dispose();
  }

  // alerts removed

  // Keep the original wishlist stream helper for the grid UI
  Stream<List<Map<String, dynamic>>> getWishlistListings() {
    final wishRef = FirebaseFirestore.instance
        .collection('wishlists')
        .where('userId', isEqualTo: widget.userId)
        .snapshots();
    return wishRef.asyncMap((wishSnap) async {
      final listingIds = wishSnap.docs
          .map((d) => d['listingId'] as String)
          .toList();
      if (listingIds.isEmpty) return [];
      final listingsSnap = await FirebaseFirestore.instance
          .collection('listings')
          .where(FieldPath.documentId, whereIn: listingIds)
          .get();
      return listingsSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> _removeFromWishlist(String listingId) async {
    final wishRef = FirebaseFirestore.instance.collection('wishlists');
    final query = await wishRef
        .where('userId', isEqualTo: widget.userId)
        .where('listingId', isEqualTo: listingId)
        .get();
    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }
  // alerts removed

  // alerts removed; no notification UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Center(
          child: Text(
            'My Wishlist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getWishlistListings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = snapshot.data ?? [];
          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No items in your wishlist yet!',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          }

          // Build notifications area + grid
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // no alert UI
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.7,
                        ),
                    itemCount: listings.length,
                    itemBuilder: (context, idx) {
                      final data = listings[idx];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListingDetailsScreen(
                                data: data,
                                listingId: data['id'],
                                // pass the listing owner's userId so buttons behave correctly
                                userId: data['userId'] ?? widget.userId,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: data['imageUrl'] ?? '',
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        height: 140,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            height: 140,
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: 32,
                                            ),
                                          ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _removeFromWishlist(data['id']),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Colors.redAccent,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title'] ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            data['size'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            data['condition'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
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
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomSheet: null,
    );
  }
}
