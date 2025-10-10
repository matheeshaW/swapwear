import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';

class EnhancedTrackDeliveryPage extends StatefulWidget {
  final String swapId;

  const EnhancedTrackDeliveryPage({super.key, required this.swapId});

  @override
  State<EnhancedTrackDeliveryPage> createState() =>
      _EnhancedTrackDeliveryPageState();
}

class _EnhancedTrackDeliveryPageState extends State<EnhancedTrackDeliveryPage> {
  final _deliveryService = DeliveryService();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        title: const Text(
          'Track Delivery',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.2),
                  const Color(0xFFD1FAE5),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<DeliveryModel?>(
        stream: _deliveryService.streamDeliveryBySwapId(widget.swapId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return _buildNoDeliveryAvailable();
          }

          final delivery = snapshot.data!;
          return _buildDeliveryTracking(delivery);
        },
      ),
    );
  }

  Widget _buildNoDeliveryAvailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 64,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Delivery tracking not available yet',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Delivery information will be available once the swap is confirmed and processed.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTracking(DeliveryModel delivery) {
    // Update map data asynchronously to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMapData(delivery);
    });

    return Column(
      children: [
        // Map Section
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMap(delivery),
            ),
          ),
        ),

        // Delivery Info Section
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDeliveryInfoCard(delivery),
                const SizedBox(height: 16),
                _buildProgressTimeline(delivery),
                const SizedBox(height: 16),
                _buildEcoImpactCard(delivery),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap(DeliveryModel delivery) {
    if (delivery.pickupLatitude == null || delivery.deliveryLatitude == null) {
      return Container(
        color: const Color(0xFFECFDF5),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 48, color: Color(0xFF10B981)),
              SizedBox(height: 16),
              Text(
                'Location data not available',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _updateMapData(delivery);
      },
      initialCameraPosition: CameraPosition(
        target: LatLng(delivery.pickupLatitude!, delivery.pickupLongitude!),
        zoom: 12,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapType: MapType.normal,
    );
  }

  void _updateMapData(DeliveryModel delivery) {
    if (delivery.pickupLatitude == null || delivery.deliveryLatitude == null) {
      return;
    }

    final pickupLatLng = LatLng(
      delivery.pickupLatitude!,
      delivery.pickupLongitude!,
    );
    final deliveryLatLng = LatLng(
      delivery.deliveryLatitude!,
      delivery.deliveryLongitude!,
    );

    // Update markers and polylines
    final newMarkers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickupLatLng,
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: delivery.pickupAddress ?? 'Pickup point',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('delivery'),
        position: deliveryLatLng,
        infoWindow: InfoWindow(
          title: 'Delivery Location',
          snippet: delivery.deliveryAddress ?? 'Delivery point',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };

    final newPolylines = <Polyline>{};
    if (delivery.routePolyline != null) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _decodePolyline(delivery.routePolyline!),
          color: const Color(0xFF10B981),
          width: 4,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _polylines = newPolylines;
      });
    }

    // Update camera asynchronously
    _updateCameraPosition(delivery);
  }

  void _updateCameraPosition(DeliveryModel delivery) {
    if (_mapController == null) return;

    try {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              delivery.pickupLatitude! < delivery.deliveryLatitude!
                  ? delivery.pickupLatitude! - 0.01
                  : delivery.deliveryLatitude! - 0.01,
              delivery.pickupLongitude! < delivery.deliveryLongitude!
                  ? delivery.pickupLongitude! - 0.01
                  : delivery.deliveryLongitude! - 0.01,
            ),
            northeast: LatLng(
              delivery.pickupLatitude! > delivery.deliveryLatitude!
                  ? delivery.pickupLatitude! + 0.01
                  : delivery.deliveryLatitude! + 0.01,
              delivery.pickupLongitude! > delivery.deliveryLongitude!
                  ? delivery.pickupLongitude! + 0.01
                  : delivery.deliveryLongitude! + 0.01,
            ),
          ),
          100,
        ),
      );
    } catch (e) {
      // Handle camera update errors silently
    }
  }

  List<LatLng> _decodePolyline(String polyline) {
    // Simple polyline decoder - in production, use a proper polyline package
    // This is a simplified version for demonstration
    return [];
  }

  Widget _buildDeliveryInfoCard(DeliveryModel delivery) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.itemName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Swap #${delivery.swapId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    delivery.status,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  delivery.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(delivery.status),
                  ),
                ),
              ),
            ],
          ),
          if (delivery.distanceKm != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.straighten,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  'Distance: ${delivery.distanceKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(DeliveryModel delivery) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ...DeliveryModel.statusSteps.asMap().entries.map((entry) {
            final index = entry.key;
            final status = entry.value;
            final isCompleted = index <= delivery.statusStep;
            final isCurrent = index == delivery.statusStep;

            return _buildTimelineStep(
              status: status,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: index == DeliveryModel.statusSteps.length - 1,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String status,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    Color getStatusColor() {
      if (isCompleted) return const Color(0xFF10B981);
      if (isCurrent) return const Color(0xFFF59E0B);
      return const Color(0xFFD1D5DB);
    }

    IconData getStatusIcon() {
      switch (status) {
        case 'Pending':
          return Icons.schedule_outlined;
        case 'Approved':
          return Icons.check_circle_outline;
        case 'Picked Up':
          return Icons.inventory_2_outlined;
        case 'In Transit':
          return Icons.local_shipping_outlined;
        case 'Delivered':
          return Icons.done_all_rounded;
        default:
          return Icons.radio_button_unchecked;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: getStatusColor(),
                shape: BoxShape.circle,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: getStatusColor().withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isCompleted ? Icons.check : getStatusIcon(),
                color: Colors.white,
                size: 18,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted
                    ? const Color(0xFF10B981)
                    : const Color(0xFFE5E7EB),
                margin: const EdgeInsets.only(top: 8),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted || isCurrent
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF6B7280),
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Currently in progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEcoImpactCard(DeliveryModel delivery) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Eco Impact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (delivery.co2SavedKg != null) ...[
            Row(
              children: [
                const Icon(Icons.cloud, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  'CO₂ Saved: ${delivery.co2SavedKg!.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(
                Icons.local_shipping,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              const Text(
                'Eco-friendly delivery method',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFF6B7280);
      case 'Approved':
        return const Color(0xFF3B82F6);
      case 'Picked Up':
        return const Color(0xFFF59E0B);
      case 'In Transit':
        return const Color(0xFF8B5CF6);
      case 'Delivered':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
