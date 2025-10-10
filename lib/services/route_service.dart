import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteService {
  // You'll need to add your Google Maps API key here
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  static Future<RouteData?> getRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    String mode = 'driving', // driving, walking, bicycling, transit
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?origin=$startLatitude,$startLongitude&destination=$endLatitude,$endLongitude&mode=$mode&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return RouteData(
            distanceKm: (leg['distance']['value'] as int) / 1000.0,
            durationMinutes: (leg['duration']['value'] as int) / 60.0,
            polyline: route['overview_polyline']['points'],
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
          );
        }
      }
    } catch (e) {
      // Handle error silently
    }
    return null;
  }

  static Future<RouteData?> getEcoRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    // Try walking first (most eco-friendly)
    var route = await getRoute(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
      mode: 'walking',
    );

    // If walking route is too long (>5km), try bicycling
    if (route == null || route.distanceKm > 5.0) {
      route = await getRoute(
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        endLatitude: endLatitude,
        endLongitude: endLongitude,
        mode: 'bicycling',
      );
    }

    // If still no route or too long (>20km), use driving
    if (route == null || route.distanceKm > 20.0) {
      route = await getRoute(
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        endLatitude: endLatitude,
        endLongitude: endLongitude,
        mode: 'driving',
      );
    }

    return route;
  }
}

class RouteData {
  final double distanceKm;
  final double durationMinutes;
  final String polyline;
  final String startAddress;
  final String endAddress;

  RouteData({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polyline,
    required this.startAddress,
    required this.endAddress,
  });

  double get co2SavedKg {
    // Calculate CO2 savings compared to standard delivery
    const double standardDeliveryCO2PerKm = 0.2; // kg CO2 per km
    const double ecoDeliveryCO2PerKm = 0.02; // kg CO2 per km for eco delivery

    return (standardDeliveryCO2PerKm - ecoDeliveryCO2PerKm) * distanceKm;
  }
}
