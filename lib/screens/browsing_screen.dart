import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';
import '../services/notification_service.dart';
import 'add_listing_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard.dart';
import '../services/admin_service.dart';
import 'listing_details_screen.dart';

class BrowsingScreen extends StatefulWidget {
  final String userId;
  final int? initialTab;
  const BrowsingScreen({super.key, required this.userId, this.initialTab});

  @override
  State<BrowsingScreen> createState() => _BrowsingScreenState();
}

class _BrowsingScreenState extends State<BrowsingScreen> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _loading = true;
  List<String> _userPreferences = [];
  String _searchQuery = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userPrefSub;

  // for wishlist state
  Set<String> wishlist = {};

  // Cache for owner display names to avoid repeated reads
  final Map<String, String> _ownerNameCache = {};
  // Filters and sorting
  String? selectedCategory;
  String? selectedSize;
  String? selectedCondition;
  String sortBy = 'Newest';

  final List<String> sizes = ['All', 'S', 'M', 'L', 'XL'];
  final List<String> conditions = ['All', 'New', 'Like New', 'Used', 'Worn'];
  final List<String> categories = [
    'All',
    'Tops',
    'Bottoms',
    'Outerwear',
    'Footwear',
    'Accessories',
  ];
  final List<String> sortOptions = ['Newest', 'Oldest'];

  @override
  void initState() {
    super.initState();
    // verify the UID used by the screen equals the auth user
    final uid = FirebaseAuth.instance.currentUser?.uid;
    assert(
      uid == widget.userId,
      'UID mismatch: auth=$uid param=${widget.userId}',
    );

    // Set initial tab if provided
    if (widget.initialTab != null) {
      _currentIndex = widget.initialTab!;
    }

    _loadUserRole();
    _loadWishlist();
    _loadUserPreferences();
    _subscribeToUserPreferences();
  }

  void _subscribeToUserPreferences() {
    _userPrefSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen(
          (doc) {
            if (!mounted) return;
            final data = doc.data();
            final prefs = <String>[];
            if (data != null && data['preferences'] != null) {
              try {
                prefs.addAll(List<String>.from(data['preferences']));
              } catch (e) {
                // ignore malformed data
              }
            }
            setState(() {
              _userPreferences = prefs;
            });
            debugPrint('Realtime prefs updated: $_userPreferences');
          },
          onError: (e) {
            debugPrint('User prefs listener error: $e');
          },
        );
  }

  Future<void> _loadUserPreferences() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc.data()?['preferences'] != null) {
        final prefs = List<String>.from(doc['preferences']);
        setState(() => _userPreferences = prefs);
        debugPrint('Loaded user preferences: $_userPreferences');
      }
    } catch (e) {
      debugPrint('Failed to load preferences: $e');
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final adminService = AdminService();
      final isAdmin = await adminService.isAdmin(widget.userId);

      debugPrint('Role check for ${widget.userId}: admin=$isAdmin');
      if (mounted)
        setState(() {
          _isAdmin = isAdmin;
          _loading = false;
        });
    } catch (e) {
      debugPrint('Role check failed: $e');
      if (mounted)
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
    }
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

  Stream<Set<String>> get wishlistStream {
    return FirebaseFirestore.instance
        .collection('wishlists')
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d['listingId'] as String).toSet());
  }

  Query getListingsQuery() {
    Query query = FirebaseFirestore.instance.collection('listings');
    final hasCategory = selectedCategory != null && selectedCategory != 'All';
    final hasSize = selectedSize != null && selectedSize != 'All';
    final hasCondition =
        selectedCondition != null && selectedCondition != 'All';

    // Note: We'll filter for availability in the client-side code to handle
    // existing listings that don't have the isAvailable field

    if (hasCategory) {
      query = query.where('category', isEqualTo: selectedCategory);
    }
    if (hasSize) {
      query = query.where('size', isEqualTo: selectedSize);
    }
    if (hasCondition) {
      query = query.where('condition', isEqualTo: selectedCondition);
    }
    // only orderBy when no filters (avoids composite index requirements)
    if (!hasCategory && !hasSize && !hasCondition) {
      query = query.orderBy('timestamp', descending: sortBy == 'Newest');
    }
    return query;
  }

  @override
  void dispose() {
    _userPrefSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleWishlist(String listingId) async {
    try {
      final col = FirebaseFirestore.instance.collection('wishlists');
      final docId = '${widget.userId}_$listingId';
      final ref = col.doc(docId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'userId': widget.userId,
            'listingId': listingId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          tx.delete(ref);
        }
      });

      // optimistic UI
      setState(() {
        if (wishlist.contains(listingId)) {
          wishlist.remove(listingId);
        } else {
          wishlist.add(listingId);
        }
      });

      // Create notification for wishlist action
      final notificationService = NotificationService();
      if (wishlist.contains(listingId)) {
        await notificationService.createNotification(
          userId: widget.userId,
          title: 'Item Added to Wishlist',
          message: 'You added an item to your wishlist!',
          type: 'Wishlist',
          tag: '#Wishlist',
          data: {'action': 'view_wishlist', 'listingId': listingId},
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Wishlist error: $e')));
    }
  }

  /// Returns the number of preference matches (tags, category, or title)
  int _preferenceMatchCount(Map<String, dynamic> data) {
    if (_userPreferences.isEmpty) return 0;

    final category = (data['category'] ?? '').toString().toLowerCase();
    final title = (data['title'] ?? '').toString().toLowerCase();

    // Safely read tags (it might be null, a list, or even a single string)
    List<String> tags = [];
    final rawTags = data['tags'];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString().toLowerCase()).toList();
    } else if (rawTags is String) {
      tags = [rawTags.toLowerCase()];
    }

    int count = 0;
    for (final pref in _userPreferences.map((p) => p.toLowerCase())) {
      if (category.contains(pref)) count++;
      if (title.contains(pref)) count++;
      count += tags.where((t) => t.contains(pref)).length;
    }
    return count;
  }

  Widget _buildOptimizedImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 30,
        ),
      );
    }

    // Try CachedNetworkImage first, but with simpler configuration
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('CachedNetworkImage error: $error for URL: $url');
        // Fallback to regular Image.network
        return Image.network(
          imageUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey.shade200,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Image.network error: $error for URL: $imageUrl');
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.image_not_supported,
                color: Colors.grey,
                size: 30,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: const Center(
        child: Text(
          'Browse Listings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    String label,
    String selectedValue,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$label',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...categories.map(
              (category) => ListTile(
                title: Text(category),
                trailing: (selectedCategory ?? 'All') == category
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => selectedCategory = category);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSizeFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Size',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...sizes.map(
              (size) => ListTile(
                title: Text(size),
                trailing: (selectedSize ?? 'All') == size
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => selectedSize = size);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConditionFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Condition',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...conditions.map(
              (condition) => ListTile(
                title: Text(condition),
                trailing: (selectedCondition ?? 'All') == condition
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => selectedCondition = condition);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseTab() {
    return Column(
      children: [
        // Green header
        _buildHeader(),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            height: 44,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
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
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
        ),
        // Filter buttons row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  'Category',
                  selectedCategory ?? 'All',
                  () => _showCategoryFilter(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton(
                  'Size',
                  selectedSize ?? 'All',
                  () => _showSizeFilter(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton(
                  'Condition',
                  selectedCondition ?? 'All',
                  () => _showConditionFilter(),
                ),
              ),
            ],
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
                        'Error loading listings.\n {snapshot.error}',
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

                  // Filter for available listings (isAvailable: true OR isAvailable field doesn't exist)
                  final availableDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isAvailable = data['isAvailable'];
                    // If isAvailable field doesn't exist, treat as available (for existing listings)
                    return isAvailable != false; // true or null/undefined
                  }).toList();

                  if (availableDocs.isEmpty) {
                    return const Center(
                      child: Text('No available listings found.'),
                    );
                  }

                  // (filters detection reserved for future use)

                  // Start with a copy
                  final sortedDocs = availableDocs.toList();

                  // Sort by number of preference matches (descending), then timestamp
                  sortedDocs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aCount = _preferenceMatchCount(aData);
                    final bCount = _preferenceMatchCount(bData);
                    if (aCount != bCount)
                      return bCount.compareTo(aCount); // Descending

                    // Fallback: timestamp sorting
                    final ta = (aData['timestamp'] as Timestamp?)?.toDate();
                    final tb = (bData['timestamp'] as Timestamp?)?.toDate();
                    if (ta == null && tb == null) return 0;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    final cmp = ta.compareTo(tb);
                    return (sortBy == 'Newest') ? -cmp : cmp;
                  });

                  // Apply search filter if present
                  List<QueryDocumentSnapshot> displayDocs = sortedDocs;
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    displayDocs = sortedDocs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final category = (data['category'] ?? '')
                          .toString()
                          .toLowerCase();
                      if (title.contains(q) || category.contains(q))
                        return true;
                      final rawTags = data['tags'];
                      if (rawTags is List) {
                        for (var t in rawTags) {
                          if (t.toString().toLowerCase().contains(q))
                            return true;
                        }
                      } else if (rawTags is String &&
                          rawTags.toLowerCase().contains(q)) {
                        return true;
                      }
                      return false;
                    }).toList();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: displayDocs.length,
                    separatorBuilder: (context, idx) =>
                        const SizedBox(height: 14),
                    cacheExtent: 1000, // Preload items for smoother scrolling
                    itemBuilder: (context, idx) {
                      final data =
                          displayDocs[idx].data() as Map<String, dynamic>;
                      final listingId = displayDocs[idx].id;
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildOptimizedImage(
                                      data['imageUrl'] ?? '',
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
                                                    ? Colors.redAccent
                                                    : Colors.grey,
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${data['category'] ?? ''} • Size ${data['size'] ?? ''} • ${data['condition'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Show the listing creator's display name (from users collection)
                                        _ownerNameWidget(
                                          data['userId'] ?? data['ownerId'],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ListingDetailsScreen(
                                                data: data,
                                                listingId: listingId,
                                                userId:
                                                    data['userId'], // pass the owner id
                                              ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    child: const Text('SWAP'),
                                  ),
                                ],
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
    );
  }

  Widget _ownerNameWidget(dynamic ownerId) {
    if (ownerId == null) {
      return const Text(
        'by @unknown',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final id = ownerId.toString();
    // if cached, return immediately
    if (_ownerNameCache.containsKey(id)) {
      return Text(
        'by @${_ownerNameCache[id]!}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    // otherwise, fetch and cache using FutureBuilder
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(id).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Text(
            'by @...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }
        final data = snap.data?.data();
        final name =
            (data?['name'] as String?) ??
            (data?['username'] as String?) ??
            'unknown';
        // cache it
        _ownerNameCache[id] = name;
        return Text(
          'by @${name}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = <Widget>[
      _buildBrowseTab(),
      WishlistScreen(userId: widget.userId),
      AddListingScreen(userId: widget.userId),
      ProfileScreen(),
      if (_isAdmin) const AdminDashboard(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Browse'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.favorite_border),
        label: 'Wishlist',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_box_outlined),
        label: 'Add',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          label: 'Admin',
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SizedBox(
          height: 40,
          child: Image.asset(
            'logo.png',
            fit: BoxFit.contain,
            // Provide semantic label for accessibility
            semanticLabel: 'SwapWear',
          ),
        ),
        actions: [
          StreamBuilder<int>(
            stream: NotificationService().streamUnreadCount(widget.userId),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.pushNamed(context, '/notifications');
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: items,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
      ),
      // ✅ Only show FAB on the browsing tab
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30), // adjust roundness
              ),
              onPressed: () {
                // switch to the Add tab inside the IndexedStack so bottom
                // navigation remains visible
                setState(() => _currentIndex = 2);
              },
              child: const Icon(Icons.add, size: 32),
            )
          : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
