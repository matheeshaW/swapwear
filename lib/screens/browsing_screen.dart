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

  final List<String> categories = [
    'All',
    'T-shirts',
    'Jackets',
    'Pants',
    'Shoes',
    'Accessories',
  ];
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
    if (selectedCategory != null && selectedCategory != 'All') {
      query = query.where('category', isEqualTo: selectedCategory);
    }
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Category filter
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory ?? 'All',
                      items: categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedCategory = val),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Size filter
                  SizedBox(
                    width: 90,
                    child: DropdownButtonFormField<String>(
                      value: selectedSize ?? 'All',
                      items: sizes
                          .map(
                            (sz) =>
                                DropdownMenuItem(value: sz, child: Text(sz)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedSize = val),
                      decoration: const InputDecoration(
                        labelText: 'Size',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Condition filter
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      value: selectedCondition ?? 'All',
                      items: conditions
                          .map(
                            (cond) => DropdownMenuItem(
                              value: cond,
                              child: Text(cond),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedCondition = val),
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort by
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      value: sortBy,
                      items: sortOptions
                          .map(
                            (sort) => DropdownMenuItem(
                              value: sort,
                              child: Text(sort),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => sortBy = val!),
                      decoration: const InputDecoration(
                        labelText: 'Sort',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: wishlistStream,
              builder: (context, wishlistSnapshot) {
                final wishlistSet = wishlistSnapshot.data ?? {};
                return StreamBuilder<QuerySnapshot>(
                  stream: getListingsQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No listings found.'));
                    }
                    final docs = snapshot.data!.docs;
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.7,
                            ),
                        itemCount: docs.length,
                        itemBuilder: (context, idx) {
                          final data = docs[idx].data() as Map<String, dynamic>;
                          final listingId = docs[idx].id;
                          return GestureDetector(
                            onTap: () => _showDetailModal(data),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                    child: Image.network(
                                      data['imageUrl'],
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
