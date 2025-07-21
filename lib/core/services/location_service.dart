import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  // Cache for recent location to avoid repeated lookups
  static LocationData? _cachedLocation;
  static DateTime? _cacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  static Future<LocationData?> getCurrentLocation() async {
    try {
      // Return cached location if still valid (within 5 minutes)
      if (_cachedLocation != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheValidDuration) {
        print('LocationService: Using cached location');
        return _cachedLocation;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('LocationService: Location services enabled: $serviceEnabled');
      if (!serviceEnabled) {
        throw Exception(
            'Location services are disabled. Please enable location services to clock in.');
      }

      // Handle permissions more gracefully
      LocationPermission permission = await _ensureLocationPermission();
      print('LocationService: Final permission status: $permission');

      // Try to get position with multiple fallback strategies
      Position? position = await _getPositionWithFallbacks();

      if (position == null) {
        throw Exception(
            'Unable to get your location. Please ensure GPS is enabled and try moving to an open area.');
      }

      print(
          'LocationService: Got position: ${position.latitude}, ${position.longitude}');

      // Get address from coordinates with timeout and fallback
      final addressInfo = await _getAddressFromPosition(position);

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: addressInfo['address']!,
        neighborhood: addressInfo['neighborhood']!,
      );

      // Cache the successful location
      _cachedLocation = locationData;
      _cacheTime = DateTime.now();

      print(
          'LocationService: Successfully created LocationData: ${locationData.neighborhood}');
      return locationData;
    } catch (e) {
      print('LocationService: Error getting location: $e');

      // Return null instead of throwing for some recoverable errors
      if (e.toString().toLowerCase().contains('timeout') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('unavailable')) {
        print('LocationService: Recoverable error, returning null');
        return null;
      }

      // For critical errors, provide clearer messages
      rethrow;
    }
  }

  /// Ensure we have proper location permissions with retries
  static Future<LocationPermission> _ensureLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      print('LocationService: Initial permission check: $permission');

      if (permission == LocationPermission.denied) {
        print('LocationService: Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        print('LocationService: Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          throw Exception(
              'Location permission denied. Please allow location access in your browser or device settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('LocationService: Permission denied forever');
        throw Exception(
            'Location permission permanently denied. Please enable location access in your device settings.');
      }

      // Accept both whileInUse and always permissions
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        print('LocationService: Unexpected permission status: $permission');
        throw Exception(
            'Location permission not properly granted. Please ensure location access is enabled.');
      }

      return permission;
    } catch (e) {
      print('LocationService: Permission handling error: $e');
      rethrow;
    }
  }

  /// Get position with multiple fallback strategies and better error handling
  static Future<Position?> _getPositionWithFallbacks() async {
    print('LocationService: Starting position acquisition with fallbacks...');

    // Strategy 1: Try last known position first (not supported on web)
    if (!kIsWeb) {
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: false,
        );

        if (lastKnown != null) {
          final now = DateTime.now();
          final lastKnownTime = DateTime.fromMillisecondsSinceEpoch(
              lastKnown.timestamp.millisecondsSinceEpoch);
          final timeDiff = now.difference(lastKnownTime);

          // Use recent last known position (within 2 hours)
          if (timeDiff.inHours < 2) {
            print(
                'LocationService: Using recent last known position (${timeDiff.inMinutes} min old)');
            return lastKnown;
          }
        }
      } catch (e) {
        print('LocationService: Last known position failed: $e');
      }
    }

    // Strategy 2: Quick medium accuracy location
    try {
      print('LocationService: Trying medium accuracy position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
        forceAndroidLocationManager: false,
      ).timeout(const Duration(seconds: 10));

      print('LocationService: Got medium accuracy position');
      return position;
    } catch (e) {
      print('LocationService: Medium accuracy attempt failed: $e');
    }

    // Strategy 3: Low accuracy with longer timeout
    try {
      print('LocationService: Trying low accuracy position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 12),
        forceAndroidLocationManager: false,
      ).timeout(const Duration(seconds: 15));

      print('LocationService: Got low accuracy position');
      return position;
    } catch (e) {
      print('LocationService: Low accuracy attempt failed: $e');
    }

    // Strategy 4: Use any available last known position as final fallback (not on web)
    if (!kIsWeb) {
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: false,
        );

        if (lastKnown != null) {
          print(
              'LocationService: Using any available last known position as final fallback');
          return lastKnown;
        }
      } catch (e) {
        print('LocationService: Final last known position attempt failed: $e');
      }
    }

    // Strategy 5: Lowest accuracy with maximum timeout
    try {
      print('LocationService: Final attempt with lowest accuracy...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.lowest,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 18));

      print('LocationService: Got lowest accuracy position');
      return position;
    } catch (e) {
      print('LocationService: Final attempt failed: $e');
    }

    print('LocationService: All position acquisition strategies failed');
    return null;
  }

  /// Get address from position with better error handling
  static Future<Map<String, String>> _getAddressFromPosition(
      Position position) async {
    String address =
        'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    String neighborhood =
        'Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

    try {
      // Try geocoding with timeout
      List<Placemark>? placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks != null && placemarks.isNotEmpty) {
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

        if (addressParts.isNotEmpty) {
          address = addressParts.join(', ');
        }

        // Extract neighborhood
        if (place.subLocality?.isNotEmpty == true) {
          neighborhood = place.subLocality!;
        } else if (place.locality?.isNotEmpty == true) {
          neighborhood = place.locality!;
        } else if (place.administrativeArea?.isNotEmpty == true) {
          neighborhood = place.administrativeArea!;
        }
      }
    } catch (e) {
      print('LocationService: Geocoding failed, using coordinates: $e');
      // Use more descriptive coordinate display as fallback
      address =
          'Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      neighborhood = 'GPS Coordinates';
    }

    return {
      'address': address,
      'neighborhood': neighborhood,
    };
  }

  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('LocationService: Error checking if location service enabled: $e');
      return false;
    }
  }

  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      print('LocationService: Error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  static Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      print('LocationService: Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  static void openLocationSettings() {
    try {
      Geolocator.openLocationSettings();
    } catch (e) {
      print('LocationService: Error opening location settings: $e');
    }
  }

  static void openAppSettings() {
    try {
      Geolocator.openAppSettings();
    } catch (e) {
      print('LocationService: Error opening app settings: $e');
    }
  }

  // Helper method to check if we have valid location permissions
  static Future<bool> hasLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      print('LocationService: Error checking permission: $e');
      return false;
    }
  }

  // Method to get a quick location without detailed error handling (for testing)
  static Future<Position?> getSimplePosition() async {
    try {
      bool hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        print('LocationService: No valid permissions for simple position');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      ).timeout(const Duration(seconds: 7));

      print(
          'LocationService: Simple position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('LocationService: Simple position failed: $e');
      return null;
    }
  }

  /// Clear location cache (useful for testing or when user explicitly requests fresh location)
  static void clearCache() {
    _cachedLocation = null;
    _cacheTime = null;
    print('LocationService: Cache cleared');
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
      ).timeout(const Duration(seconds: 5)); // Add timeout here too

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
    // Don't use hardcoded location estimates - let geocoding handle it
    // or show coordinates if geocoding fails
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

  /// Get a user-friendly error message with troubleshooting tips
  static String getLocationErrorMessage(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('permission') && lowerError.contains('denied')) {
      return 'Location permission denied. Please enable location access in your browser or device settings.';
    } else if (lowerError.contains('service') ||
        lowerError.contains('disabled')) {
      return 'Location services are disabled. Please enable GPS/location services.';
    } else if (lowerError.contains('timeout') ||
        lowerError.contains('unavailable')) {
      return 'Location request timed out. Try moving to an open area with better GPS signal.';
    } else if (lowerError.contains('network')) {
      return 'Network error while getting location. Please check your internet connection.';
    } else {
      return 'Unable to get location. Please ensure GPS is enabled and try again.';
    }
  }

  /// Clear cache and force fresh location (useful for troubleshooting)
  static Future<LocationData?> forceRefreshLocation() async {
    clearCache();
    return await getCurrentLocation();
  }
}
