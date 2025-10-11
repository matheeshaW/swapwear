import 'package:flutter/material.dart';
import '../services/swap_service.dart';
import 'location_picker_screen.dart';

class LocationSelectionModal extends StatefulWidget {
  final String swapId;
  final String userId;

  const LocationSelectionModal({
    super.key,
    required this.swapId,
    required this.userId,
  });

  @override
  State<LocationSelectionModal> createState() => _LocationSelectionModalState();
}

class _LocationSelectionModalState extends State<LocationSelectionModal> {
  final TextEditingController _locationController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _locationController.addListener(() {
      final hasText = _locationController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _setManualLocation() {
    final location = _locationController.text.trim();
    if (location.isNotEmpty) {
      _submitLocation(location, 6.9271, 79.8612); // Dummy coordinates
    }
  }

  Future<void> _selectFromMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          swapId: widget.swapId,
          itemName: 'Swap Item',
          providerName: 'Provider',
          receiverName: 'Receiver',
        ),
      ),
    );

    if (result != null && mounted) {
      _locationController.text = result['address'];
      _submitLocation(
        result['address'],
        result['latitude'] as double,
        result['longitude'] as double,
      );
    }
  }

  Future<void> _submitLocation(String address, double lat, double lng) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await SwapService().addUserLocation(
        swapId: widget.swapId,
        userId: widget.userId,
        latitude: lat,
        longitude: lng,
        address: address,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D9D78).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF2D9D78),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Choose Your Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Please provide your delivery location to complete the swap.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Location Input
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Enter delivery address (e.g., 123 Main St, City)',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(
                  Icons.location_on,
                  color: Color(0xFF2D9D78),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF2D9D78),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _selectFromMap,
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Choose from Map'),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting || !_hasText
                        ? null
                        : _setManualLocation,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Use Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasText
                          ? const Color(0xFF2D9D78)
                          : const Color(0xFF9CA3AF),
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

            if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Color(0xFF2D9D78)),
            ],
          ],
        ),
      ),
    );
  }
}
