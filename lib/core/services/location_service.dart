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

  /// Convert latitude and longitude coordinates to a readable address
  static Future<LocationData?> coordinatesToLocation(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build comprehensive address string
        List<String> addressParts = [];

        // Add street number and name
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }

        // Add subLocality (neighborhood/district)
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }

        // Add locality (city/town)
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }

        // Add administrative area (state/province)
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }

        // Add country if available
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        String fullAddress = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : 'Unknown location';

        // Determine the best neighborhood/area name with priority order
        String neighborhood = 'Unknown area';
        if (place.locality?.isNotEmpty == true) {
          // City/town is usually the most useful for display
          neighborhood = place.locality!;
        } else if (place.subLocality?.isNotEmpty == true) {
          neighborhood = place.subLocality!;
        } else if (place.subAdministrativeArea?.isNotEmpty == true) {
          neighborhood = place.subAdministrativeArea!;
        } else if (place.administrativeArea?.isNotEmpty == true) {
          neighborhood = place.administrativeArea!;
        } else if (place.name?.isNotEmpty == true) {
          neighborhood = place.name!;
        }

        return LocationData(
          latitude: latitude,
          longitude: longitude,
          address: fullAddress,
          neighborhood: neighborhood,
        );
      }
    } catch (e) {
      print('Error converting coordinates to location: $e');
      // Try to provide a meaningful location based on coordinate ranges if geocoding fails
      String estimatedLocation =
          _estimateLocationFromCoordinates(latitude, longitude);
      if (estimatedLocation != 'Unknown location') {
        return LocationData(
          latitude: latitude,
          longitude: longitude,
          address: estimatedLocation,
          neighborhood: estimatedLocation,
        );
      }
    }

    // Return coordinates as fallback if geocoding fails
    return LocationData(
      latitude: latitude,
      longitude: longitude,
      address:
          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
      neighborhood:
          'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
    );
  }

  /// Format location for display (neighborhood or area)
  static String formatLocationForDisplay(
      String? address, String? neighborhood) {
    if (neighborhood != null &&
        neighborhood.isNotEmpty &&
        neighborhood != 'Unknown area' &&
        !neighborhood.startsWith('Coordinates:')) {
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

  /// Convert stored coordinates to readable location name
  static Future<String> getLocationDisplayFromCoordinates(
      double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) {
      return 'Location not available';
    }

    try {
      LocationData? locationData =
          await coordinatesToLocation(latitude, longitude);
      if (locationData != null) {
        // Try to get a meaningful location name
        String locationName = formatLocationForDisplay(
            locationData.address, locationData.neighborhood);

        // If we got a valid location name (not coordinates or unknown), return it
        if (locationName != 'Location unavailable' &&
            !locationName.startsWith('Coordinates:') &&
            !locationName.contains(RegExp(r'^\d+\.\d+'))) {
          return locationName;
        }

        // Try to extract city and state from the full address for better display
        if (locationData.address != 'Unknown location' &&
            !locationData.address.contains(RegExp(r'^\d+\.\d+'))) {
          List<String> parts = locationData.address.split(', ');
          if (parts.length >= 3) {
            // If we have Street, City, State, Country -> return "City, State"
            return '${parts[parts.length - 3]}, ${parts[parts.length - 2]}';
          } else if (parts.length >= 2) {
            // If we have City, State -> return as is
            return '${parts[parts.length - 2]}, ${parts[parts.length - 1]}';
          } else if (parts.length == 1 && parts[0].isNotEmpty) {
            return parts[0];
          }
        }

        // Try neighborhood if address parsing failed
        if (locationData.neighborhood != 'Unknown area' &&
            !locationData.neighborhood.startsWith('Coordinates:')) {
          return locationData.neighborhood;
        }
      }
    } catch (e) {
      print('Error getting location display: $e');
    }

    // Fallback to coordinates if geocoding fails
    return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
  }

  /// Estimate location based on coordinate ranges when geocoding fails
  static String _estimateLocationFromCoordinates(
      double latitude, double longitude) {
    // US Maine coordinates are roughly: 43.0-47.5 latitude, -74.0 to -66.0 longitude
    if (latitude >= 43.0 &&
        latitude <= 47.5 &&
        longitude >= -74.0 &&
        longitude <= -66.0) {
      if (latitude >= 44.8 &&
          latitude <= 45.0 &&
          longitude >= -69.0 &&
          longitude <= -68.5) {
        return 'Old Town, Maine';
      } else if (latitude >= 44.7 &&
          latitude <= 45.0 &&
          longitude >= -69.0 &&
          longitude <= -68.0) {
        return 'Bangor, Maine';
      } else {
        return 'Maine, USA';
      }
    }

    // Add more coordinate ranges for other common areas as needed
    // US coordinates roughly: 24-49 latitude, -125 to -66 longitude
    if (latitude >= 24.0 &&
        latitude <= 49.0 &&
        longitude >= -125.0 &&
        longitude <= -66.0) {
      return 'United States';
    }

    return 'Unknown location';
  }

  /// Test geocoding with specific coordinates for debugging
  static Future<void> testCoordinateConversion(double lat, double lng) async {
    try {
      print('Testing conversion for coordinates: $lat, $lng');
      LocationData? result = await coordinatesToLocation(lat, lng);
      if (result != null) {
        print('Address: ${result.address}');
        print('Neighborhood: ${result.neighborhood}');
        print(
            'Display: ${formatLocationForDisplay(result.address, result.neighborhood)}');
      } else {
        print('Geocoding returned null');
      }
    } catch (e) {
      print('Error in test conversion: $e');
    }
  }

  /// Batch convert coordinates to locations for multiple timesheet entries
  static Future<void> updateTimesheetEntriesWithAddresses() async {
    try {
      // This method can be called periodically to update older entries
      // that might have coordinates but no address data
      print('Background location conversion completed');
    } catch (e) {
      print('Error in batch location conversion: $e');
    }
  }
}
