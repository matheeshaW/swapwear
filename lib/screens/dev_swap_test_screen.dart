import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/swap_service.dart';

class DevSwapTestScreen extends StatefulWidget {
  const DevSwapTestScreen({super.key});

  @override
  State<DevSwapTestScreen> createState() => _DevSwapTestScreenState();
}

class _DevSwapTestScreenState extends State<DevSwapTestScreen> {
  String? _requestedListingId;
  String? _offeredListingId;
  String? _requestedOwnerId;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final currentUserId = currentUser.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Dev Swap Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Requested Listing:'),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('listings')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, idx) {
                      final data = docs[idx].data() as Map<String, dynamic>;
                      final id = docs[idx].id;
                      final owner = data['userId'] ?? '';
                      final title = data['title'] ?? '';
                      return ListTile(
                        title: Text(title),
                        subtitle: Text('Owner: $owner'),
                        selected: _requestedListingId == id,
                        onTap: () {
                          setState(() {
                            _requestedListingId = id;
                            _requestedOwnerId = owner;
                          });
                        },
                        trailing: _requestedListingId == id
                            ? const Icon(Icons.check)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Your Offered Listing:'),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('listings')
                    .where('userId', isEqualTo: currentUserId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, idx) {
                      final data = docs[idx].data() as Map<String, dynamic>;
                      final id = docs[idx].id;
                      final title = data['title'] ?? '';
                      return ListTile(
                        title: Text(title),
                        selected: _offeredListingId == id,
                        onTap: () {
                          setState(() {
                            _offeredListingId = id;
                          });
                        },
                        trailing: _offeredListingId == id
                            ? const Icon(Icons.check)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed:
                    (_requestedListingId != null &&
                        _offeredListingId != null &&
                        _requestedOwnerId != null &&
                        _requestedOwnerId != currentUserId)
                    ? () async {
                        try {
                          final swapId = await SwapService().createSwapRequest(
                            fromUserId: currentUserId,
                            toUserId: _requestedOwnerId!,
                            listingOfferedId: _offeredListingId!,
                            listingRequestedId: _requestedListingId!,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Swap created')),
                          );
                          Navigator.of(
                            context,
                          ).pushNamed('/chat', arguments: {'chatId': swapId});
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    : null,
                child: const Text('Request Swap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
