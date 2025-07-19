import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final String neighborhood;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.neighborhood,
  });
}

class LocationService {
  static Future<LocationData?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
            'Location services are disabled. Please enable location services to clock in.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
              'Location permission denied. Please allow location access to clock in.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permission permanently denied. Please enable location access in settings to clock in.');
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
      String address = 'Unknown location';
      String neighborhood = 'Unknown area';

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          // Build address string
          List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }

          address = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : 'Unknown location';

          // Extract neighborhood (subLocality or locality)
          neighborhood = place.subLocality?.isNotEmpty == true
              ? place.subLocality!
              : (place.locality?.isNotEmpty == true
                  ? place.locality!
                  : 'Unknown area');
        }
      } catch (e) {
        print('Error getting address: $e');
        // Continue with coordinates even if address lookup fails
        address =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        neighborhood =
            'Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        neighborhood: neighborhood,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  static void openLocationSettings() {
    Geolocator.openLocationSettings();
  }

  static void openAppSettings() {
    Geolocator.openAppSettings();
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Format location for display (neighborhood or area)
  static String formatLocationForDisplay(
      String? address, String? neighborhood) {
    if (neighborhood != null &&
        neighborhood.isNotEmpty &&
        neighborhood != 'Unknown area') {
      return neighborhood;
    }
    if (address != null &&
        address.isNotEmpty &&
        address != 'Unknown location') {
      // Extract the most relevant part of address for display
      final parts = address.split(', ');
      if (parts.length >= 2) {
        return parts[1]; // Usually the neighborhood/area
      }
      return parts[0];
    }
    return 'Location unavailable';
  }
}
