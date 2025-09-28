import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import 'add_listing_screen.dart'; // Added import for AddListingScreen
import 'wishlist_screen.dart';

class BrowsingScreen extends StatefulWidget {
  final String userId;
  const BrowsingScreen({super.key, required this.userId});

  @override
  State<BrowsingScreen> createState() => _BrowsingScreenState();
}

class _BrowsingScreenState extends State<BrowsingScreen> {
  // For wishlist state
  Set<String> wishlist = {};

  // Filters and sorting
  String? selectedCategory;
  String? selectedSize;
  String? selectedCondition;
  String sortBy = 'Newest';

  final List<String> sizes = ['All', 'S', 'M', 'L', 'XL'];
  final List<String> conditions = ['All', 'New', 'Like New', 'Used', 'Worn'];
  final List<String> sortOptions = ['Newest', 'Oldest'];

  Stream<Set<String>> get wishlistStream {
    return FirebaseFirestore.instance
        .collection('wishlists')
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d['listingId'] as String).toSet());
  }

  Query getListingsQuery() {
    Query query = FirebaseFirestore.instance.collection('listings');
    if (selectedSize != null && selectedSize != 'All') {
      query = query.where('size', isEqualTo: selectedSize);
    }
    if (selectedCondition != null && selectedCondition != 'All') {
      query = query.where('condition', isEqualTo: selectedCondition);
    }
    query = query.orderBy('timestamp', descending: sortBy == 'Newest');
    return query;
  }

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    final snap = await FirebaseFirestore.instance
        .collection('wishlists')
        .where('userId', isEqualTo: widget.userId)
        .get();
    setState(() {
      wishlist = snap.docs.map((d) => d['listingId'] as String).toSet();
    });
  }

  Future<void> _toggleWishlist(String listingId) async {
    final wishRef = FirebaseFirestore.instance.collection('wishlists');
    final query = await wishRef
        .where('userId', isEqualTo: widget.userId)
        .where('listingId', isEqualTo: listingId)
        .get();
    if (query.docs.isEmpty) {
      await wishRef.add({
        'userId': widget.userId,
        'listingId': listingId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => wishlist.add(listingId));
    } else {
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
      setState(() => wishlist.remove(listingId));
    }
  }

  void _showDetailModal(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  data['imageUrl'],
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              data['title'] ?? '',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text('Size: ${data['size']}'),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('Condition: ${data['condition']}'),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data['description'] != null)
              Text(
                data['description'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null, // Not implemented
                child: const Text('Request Swap'),
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
      appBar: AppBar(
        title: Row(
          children: [
            // You can replace with Image.asset('assets/logo.png', height: 32) if you have a logo
            const Icon(Icons.swap_horiz, color: AppColors.white),
            const SizedBox(width: 8),
            const Text('SwapWear'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Wishlist',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WishlistScreen(userId: widget.userId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {}, // For future search
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              height: 44,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search apparel... ',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  // Optionally implement search logic
                },
              ),
            ),
          ),
          // Modern filter & sort bar (no category, all options visible, wrap if needed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: AppColors.secondary,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        // Size filter as ChoiceChips
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Size:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            ...['All', 'S', 'M', 'L', 'XL'].map(
                              (sz) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: ChoiceChip(
                                  label: Text(sz),
                                  selected: (selectedSize ?? 'All') == sz,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  labelStyle: TextStyle(
                                    color: (selectedSize ?? 'All') == sz
                                        ? Colors.white
                                        : AppColors.accent,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => selectedSize = sz),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Condition filter as ChoiceChips
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Condition:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  ...[
                                    'All',
                                    'New',
                                    'Like New',
                                    'Used',
                                    'Worn',
                                  ].map(
                                    (cond) => ChoiceChip(
                                      label: Text(cond),
                                      selected:
                                          (selectedCondition ?? 'All') == cond,
                                      selectedColor: AppColors.primary,
                                      backgroundColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color:
                                            (selectedCondition ?? 'All') == cond
                                            ? Colors.white
                                            : AppColors.accent,
                                      ),
                                      onSelected: (_) => setState(
                                        () => selectedCondition = cond,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Sort by as pill toggle
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Sort:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            ToggleButtons(
                              borderRadius: BorderRadius.circular(18),
                              isSelected: [
                                sortBy == 'Newest',
                                sortBy == 'Oldest',
                              ],
                              selectedColor: Colors.white,
                              fillColor: AppColors.primary,
                              color: AppColors.accent,
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Newest'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Oldest'),
                                ),
                              ],
                              onPressed: (idx) {
                                setState(
                                  () => sortBy = idx == 0 ? 'Newest' : 'Oldest',
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Listings feed
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: wishlistStream,
              builder: (context, wishlistSnapshot) {
                final wishlistSet = wishlistSnapshot.data ?? {};
                return StreamBuilder<QuerySnapshot>(
                  stream: getListingsQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading listings.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No listings found.'));
                    }
                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: docs.length,
                      separatorBuilder: (context, idx) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, idx) {
                        final data = docs[idx].data() as Map<String, dynamic>;
                        final listingId = docs[idx].id;
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    data['imageUrl'],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
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
                                          ),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () =>
                                                _toggleWishlist(listingId),
                                            child: Icon(
                                              wishlistSet.contains(listingId)
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color:
                                                  wishlistSet.contains(
                                                    listingId,
                                                  )
                                                  ? AppColors.primary
                                                  : Colors.grey,
                                              size: 22,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () =>
                                                _showDetailModal(data),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 8,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            child: const Text('View Details'),
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Modern bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: 0, // You can make this dynamic if you add navigation
        onTap: (idx) {
          if (idx == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WishlistScreen(userId: widget.userId),
              ),
            );
          } else if (idx == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddListingScreen(userId: widget.userId),
              ),
            );
          }
          // Add navigation for other tabs as needed
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddListingScreen(userId: widget.userId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Listing'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
