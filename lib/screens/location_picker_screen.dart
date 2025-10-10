import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final String swapId;
  final String itemName;
  final String providerName;
  final String receiverName;

  const LocationPickerScreen({
    super.key,
    required this.swapId,
    required this.itemName,
    required this.providerName,
    required this.receiverName,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = false;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _selectedLocation = _currentLocation;
        });

        // Get address for current location asynchronously
        _getAddressForLocation(position.latitude, position.longitude);
        _updateMarkers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getAddressForLocation(double latitude, double longitude) async {
    try {
      final address = await LocationService.getAddressFromCoordinates(
        latitude,
        longitude,
      );
      if (mounted) {
        setState(() => _selectedAddress = address);
      }
    } catch (e) {
      // Handle error silently or show a subtle message
      if (mounted) {
        setState(() => _selectedAddress = 'Address not available');
      }
    }
  }

  void _updateMarkers() {
    if (_selectedLocation != null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selected'),
            position: _selectedLocation!,
            infoWindow: InfoWindow(
              title: 'Delivery Location',
              snippet: _selectedAddress ?? 'Selected location',
            ),
          ),
        };
      });
    }
  }

  void _onMapTap(LatLng location) {
    // Debounce rapid taps
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500) {
      return;
    }
    _lastTapTime = now;

    setState(() {
      _selectedLocation = location;
      _selectedAddress = 'Loading address...';
    });

    _updateMarkers();

    // Get address for selected location asynchronously
    _getAddressForLocation(location.latitude, location.longitude);
  }

  Future<void> _confirmLocation() async {
    if (_selectedLocation == null) return;

    setState(() => _isLoading = true);

    try {
      // Calculate distance and CO2 savings
      double distanceKm = 0;
      double co2SavedKg = 0;

      if (_currentLocation != null) {
        distanceKm = LocationService.calculateDistance(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        );
        co2SavedKg = LocationService.calculateCO2Saved(distanceKm);
      }

      // Get route data asynchronously (don't wait for it)
      RouteData? routeData;
      if (_currentLocation != null) {
        // Run route calculation in background
        RouteService.getEcoRoute(
          startLatitude: _currentLocation!.latitude,
          startLongitude: _currentLocation!.longitude,
          endLatitude: _selectedLocation!.latitude,
          endLongitude: _selectedLocation!.longitude,
        ).then((data) {
          // Route data will be available later if needed
          routeData = data;
        });
      }

      // Return the selected location data immediately
      if (mounted) {
        Navigator.pop(context, {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'address': _selectedAddress ?? 'Selected location',
          'distanceKm': distanceKm,
          'co2SavedKg': co2SavedKg,
          'routePolyline': routeData?.polyline,
          'estimatedDuration': routeData?.durationMinutes,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        title: const Text(
          'Select Delivery Location',
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
      body: Column(
        children: [
          // Item Info Card
          Container(
            margin: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${widget.providerName} to ${widget.receiverName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: _currentLocation == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  )
                : GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      // Map controller initialized
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation!,
                      zoom: 15,
                    ),
                    onTap: _onMapTap,
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                  ),
          ),

          // Selected Location Info
          if (_selectedLocation != null)
            Container(
              margin: const EdgeInsets.all(16),
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
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Selected Location:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddress ?? 'Loading address...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),

          // Confirm Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedLocation != null && !_isLoading
                    ? _confirmLocation
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
