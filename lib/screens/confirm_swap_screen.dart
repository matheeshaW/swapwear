import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/swap_service.dart';

class ConfirmSwapScreen extends StatelessWidget {
  final String swapId;
  final String listingOfferedId;
  final String listingRequestedId;
  const ConfirmSwapScreen({
    super.key,
    required this.swapId,
    required this.listingOfferedId,
    required this.listingRequestedId,
  });

  Future<Map<String, dynamic>?> _getListing(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(id)
        .get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Swap')),
      body: FutureBuilder<List<Map<String, dynamic>?>>(
        future: Future.wait([
          _getListing(listingOfferedId),
          _getListing(listingRequestedId),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final offered = snapshot.data?[0] ?? {};
          final requested = snapshot.data?[1] ?? {};

          Widget buildCard(Map<String, dynamic> data, String label) {
            final title = (data['title'] ?? 'Unknown').toString();
            final size = (data['size'] ?? '').toString();
            final condition = (data['condition'] ?? '').toString();
            final image = (data['imageUrl'] ?? '').toString();
            return Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 1.2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: image.isNotEmpty
                            ? Image.network(image, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (size.isNotEmpty)
                      Text(
                        'Size: $size',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    if (condition.isNotEmpty)
                      Text(
                        'Condition: $condition',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    buildCard(offered, 'Offered Item'),
                    const SizedBox(width: 12),
                    buildCard(requested, 'Requested Item'),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Do you confirm this swap?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await SwapService().confirmSwap(swapId);
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Swap will only be finalized when both parties confirm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
