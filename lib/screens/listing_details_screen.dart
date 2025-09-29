import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/swap_service.dart';

class ListingDetailsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    print("CurrentUser:  [32m");
    print(FirebaseAuth.instance.currentUser?.uid);
    print("Listing Owner: $userId");

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
                onPressed: () =>
                    Navigator.pop(context, listing['id'] as String),
                child: Text(listing['title'] ?? 'Untitled'),
              );
            }).toList(),
          );
        },
      );
    }

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
                data['imageUrl'],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
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
                  label: Text('Size: ${data['size'] ?? '-'}'),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('Condition: ${data['condition'] ?? '-'}'),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((data['category'] ?? '') is String &&
                    (data['category'] ?? '').isNotEmpty)
                  Chip(
                    label: Text('Category: ${data['category']}'),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  ),
                ...((data['tags'] is List)
                        ? (data['tags'] as List).cast<dynamic>()
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
            if (data['description'] != null)
              Text(
                data['description'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You must be logged in.')),
                    );
                    return;
                  }
                  if (userId == currentUser.uid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot swap your own listing.'),
                      ),
                    );
                    return;
                  }
                  final userListings = await fetchUserListings(currentUser.uid);
                  if (userListings.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You have no listings to offer!'),
                      ),
                    );
                    return;
                  }
                  final offeredId = await showOfferedListingPicker(
                    context,
                    userListings,
                  );
                  if (offeredId == null) return; // User cancelled
                  try {
                    await SwapService().createSwapRequest(
                      fromUserId: currentUser.uid,
                      toUserId: userId,
                      listingOfferedId: offeredId,
                      listingRequestedId: listingId,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Swap request sent!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send swap request: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Request Swap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
