import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/swap_service.dart';
import '../services/delivery_service.dart';
import 'location_picker_screen.dart';

class ConfirmSwapScreen extends StatefulWidget {
  final String swapId;
  final String listingOfferedId;
  final String listingRequestedId;

  const ConfirmSwapScreen({
    super.key,
    required this.swapId,
    required this.listingOfferedId,
    required this.listingRequestedId,
  });

  @override
  State<ConfirmSwapScreen> createState() => _ConfirmSwapScreenState();
}

class _ConfirmSwapScreenState extends State<ConfirmSwapScreen> {
  bool _hasDeliveryLocation = false;
  String? _deliveryAddress;
  bool _isConfirming = false;

  Future<Map<String, dynamic>> _getListing(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(id)
          .get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('Error loading listing: $e');
      return {};
    }
  }

  Future<void> _selectDeliveryLocation(
    Map<String, dynamic> offeredListing,
  ) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          swapId: widget.swapId,
          itemName: offeredListing['title'] ?? 'Item',
          providerName: offeredListing['userName'] ?? 'Provider',
          receiverName: 'You',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _hasDeliveryLocation = true;
        _deliveryAddress = result['address'];
      });
    }
  }

  Future<void> _confirmSwap() async {
    if (_isConfirming) return;

    setState(() => _isConfirming = true);

    try {
      await SwapService().confirmSwap(widget.swapId);

      if (_hasDeliveryLocation && _deliveryAddress != null) {
        await DeliveryService().updateDeliveryLocation(
          swapId: widget.swapId,
          deliveryAddress: _deliveryAddress!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Swap confirmed successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error confirming swap: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  Widget _buildItemCard(
    Map<String, dynamic> data,
    String label,
    Color accentColor,
  ) {
    final title = data['title']?.toString() ?? 'Unknown';
    final size = data['size']?.toString() ?? '';
    final condition = data['condition']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? '';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: accentColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Image
            AspectRatio(
              aspectRatio: 1.2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: accentColor.withOpacity(0.05),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor.withOpacity(0.1),
                                accentColor.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: accentColor.withOpacity(0.4),
                          ),
                        ),
                        memCacheWidth: 400,
                        memCacheHeight: 400,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.1),
                              accentColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: accentColor.withOpacity(0.4),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A5C4A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Size
            if (size.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Size: $size',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Condition
            if (condition.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    condition,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryLocationSection(Map<String, dynamic> offered) {
    if (!_hasDeliveryLocation) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2D9D78).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.location_on, color: Color(0xFF2D9D78), size: 20),
                SizedBox(width: 8),
                Text(
                  'Add Delivery Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A5C4A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select where you\'d like to meet for the swap',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _selectDeliveryLocation(offered),
                icon: const Icon(Icons.map, size: 18),
                label: const Text('Choose Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D9D78),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Location Set',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46),
                  ),
                ),
                if (_deliveryAddress != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _deliveryAddress!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => _selectDeliveryLocation(offered),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9F6),
      appBar: AppBar(
        title: const Text(
          'Confirm Swap',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A5C4A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A5C4A)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait([
          _getListing(widget.listingOfferedId),
          _getListing(widget.listingRequestedId),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D9D78)),
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
                  const Text(
                    'Error loading swap details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

          final offered = snapshot.data?[0] ?? {};
          final requested = snapshot.data?[1] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Eco-friendly badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D9D78), Color(0xFF3FB897)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2D9D78).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Sustainable Exchange',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Swap items
                Row(
                  children: [
                    _buildItemCard(
                      requested,
                      'YOUR ITEM',
                      const Color(0xFF2D9D78),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ECDC4).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            color: Color(0xFF2D9D78),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    _buildItemCard(
                      offered,
                      'THEIR ITEM',
                      const Color(0xFF4ECDC4),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Confirmation section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Ready to complete this swap?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A5C4A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Delivery Location Section
                      _buildDeliveryLocationSection(offered),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _hasDeliveryLocation && !_isConfirming
                                  ? _confirmSwap
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D9D78),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: _isConfirming
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _hasDeliveryLocation
                                              ? Icons.check_circle_outline
                                              : Icons.location_off,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _hasDeliveryLocation
                                              ? 'Confirm Swap'
                                              : 'Add Location First',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _isConfirming
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE85D75),
                              padding: const EdgeInsets.all(16),
                              side: const BorderSide(
                                color: Color(0xFFE85D75),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.close, size: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Info message
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFF2D9D78),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Swap will be finalized when both parties confirm',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
