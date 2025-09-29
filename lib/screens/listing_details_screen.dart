import 'package:flutter/material.dart';
import '../theme/colors.dart';

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
                onPressed: null,
                child: const Text('Request Swap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
