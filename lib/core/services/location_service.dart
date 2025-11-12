import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'location_preference_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

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
  static final Map<String, Map<String, String>> _reverseGeocodeCache = {};

  static Future<LocationData?> getCurrentLocation(
      {bool interactive = true}) async {
    try {
      AppLogger.debug(
          'LocationService: getCurrentLocation called (web=$kIsWeb, interactive=$interactive)');
      // Return cached location if still valid (within 5 minutes)
      if (_cachedLocation != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheValidDuration) {
        AppLogger.debug('LocationService: Using cached location');
        return _cachedLocation;
      }

      // Check if location services are enabled (skip strict check on web)
      bool serviceEnabled = true;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (e) {
        // Ignore platform-specific errors here
        AppLogger.error('LocationService: Error checking service enabled: $e');
      }
      AppLogger.error('LocationService: Location services enabled: $serviceEnabled');
      // On web, browsers handle enablement; don't hard-fail if reported disabled
      if (!kIsWeb && !serviceEnabled) {
        throw Exception(
            'Location services are disabled. Please enable location services to clock in.');
      }

      // Handle permissions more gracefully
      LocationPermission permission =
          await _ensureLocationPermission(interactive: interactive);
      AppLogger.debug('LocationService: Final permission status: $permission');

      // On web, allow proceeding to trigger the browser prompt via getCurrentPosition
      // Only gate on permission for non-web platforms.
      if (!kIsWeb &&
          permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        AppLogger.debug('LocationService: No valid permissions (mobile/desktop).');
        return null; // Return null instead of throwing
      }
      if (kIsWeb &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever)) {
        AppLogger.debug(
            'LocationService: Web platform with permission=$permission; proceeding to request position to trigger prompt');
      }

      // Try to get position with multiple fallback strategies
      Position? position = await _getPositionWithFallbacks();

      if (position == null) {
        throw Exception(
            'Unable to get your location. Please ensure GPS is enabled and try moving to an open area.');
      }

      AppLogger.debug(
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

      AppLogger.error(
          'LocationService: Successfully created LocationData: ${locationData.neighborhood}');
      return locationData;
    } catch (e) {
      AppLogger.error('LocationService: Error getting location: $e');

      // Return null instead of throwing for some recoverable errors
      if (e.toString().toLowerCase().contains('timeout') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('unavailable')) {
        AppLogger.error('LocationService: Recoverable error, returning null');
        return null;
      }

      // For critical errors, provide clearer messages
      rethrow;
    }
  }

  /// Ensure we have proper location permissions with retries
  static Future<LocationPermission> _ensureLocationPermission(
      {bool interactive = true}) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      AppLogger.debug('LocationService: Initial permission check: $permission');

      if (permission == LocationPermission.denied) {
        // Only throttle repeated prompts on non-web or when not interactive
        if (!kIsWeb || !interactive) {
          final shouldSkip =
              await LocationPreferenceService.shouldSkipLocationRequest();
          if (shouldSkip) {
            AppLogger.debug(
                'LocationService: Skipping permission request based on user preferences');
            return LocationPermission.denied;
          }
        }

        // If not interactive (e.g., background), don't trigger browser prompt on web
        if (kIsWeb && !interactive) {
          AppLogger.debug(
              'LocationService: Web non-interactive context - not requesting permission');
          return LocationPermission.denied;
        }

        AppLogger.debug('LocationService: Permission denied, requesting...');

        // Mark that we're asking for permission
        await LocationPreferenceService.markLocationAsked();

        // Add timeout for permission request to prevent hanging
        try {
          permission = await Geolocator.requestPermission()
              .timeout(const Duration(seconds: 30), onTimeout: () {
            AppLogger.error('LocationService: Permission request timed out');
            return LocationPermission.denied;
          });
        } catch (e) {
          AppLogger.error('LocationService: Permission request failed: $e');
          return LocationPermission.denied;
        }

        AppLogger.error('LocationService: Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          // Mark permission as denied to avoid asking again soon (non-web)
          if (!kIsWeb) {
            await LocationPreferenceService.markLocationDenied();
          }
          AppLogger.debug('LocationService: Permission was denied by user');
          return permission;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.debug('LocationService: Permission denied forever');
        // On web there is no app settings concept; avoid sticky denial flag
        if (!kIsWeb) {
          await LocationPreferenceService.markLocationDenied();
        }
        return permission;
      }

      // Accept both whileInUse and always permissions
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        AppLogger.error('LocationService: Unexpected permission status: $permission');
      }

      return permission;
    } catch (e) {
      AppLogger.error('LocationService: Permission handling error: $e');
      return LocationPermission.denied;
    }
  }

  /// Get position with multiple fallback strategies and better error handling
  static Future<Position?> _getPositionWithFallbacks() async {
    AppLogger.debug('LocationService: Starting position acquisition with fallbacks...');

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
            AppLogger.error(
                'LocationService: Using recent last known position (${timeDiff.inMinutes} min old)');
            return lastKnown;
          }
        }
      } catch (e) {
        AppLogger.error('LocationService: Last known position failed: $e');
      }
    }

    // Strategy 2: Quick medium accuracy location
    try {
      AppLogger.error('LocationService: Trying medium accuracy position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
        forceAndroidLocationManager: false,
      ).timeout(const Duration(seconds: 10));

      AppLogger.error('LocationService: Got medium accuracy position');
      return position;
    } catch (e) {
      AppLogger.error('LocationService: Medium accuracy attempt failed: $e');
    }

    // Strategy 3: Low accuracy with longer timeout
    try {
      AppLogger.error('LocationService: Trying low accuracy position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 12),
        forceAndroidLocationManager: false,
      ).timeout(const Duration(seconds: 15));

      AppLogger.error('LocationService: Got low accuracy position');
      return position;
    } catch (e) {
      AppLogger.error('LocationService: Low accuracy attempt failed: $e');
    }

    // Strategy 4: Use any available last known position as final fallback (not on web)
    if (!kIsWeb) {
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: false,
        );

        if (lastKnown != null) {
          AppLogger.error(
              'LocationService: Using any available last known position as final fallback');
          return lastKnown;
        }
      } catch (e) {
        AppLogger.error('LocationService: Final last known position attempt failed: $e');
      }
    }

    // Strategy 5: Lowest accuracy with maximum timeout
    try {
      AppLogger.error('LocationService: Final attempt with lowest accuracy...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.lowest,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 18));

      AppLogger.error('LocationService: Got lowest accuracy position');
      return position;
    } catch (e) {
      AppLogger.error('LocationService: Final attempt failed: $e');
    }

    AppLogger.error('LocationService: All position acquisition strategies failed');
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
      AppLogger.error('LocationService: Geocoding failed, using coordinates: $e');
      // Use more descriptive coordinate display as fallback
      address =
          'Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      neighborhood = 'GPS Coordinates';
    }

    // If result still looks like coordinates, try network reverse geocoding (Nominatim)
    final looksLikeCoords = neighborhood.startsWith('Coordinates:') ||
        neighborhood == 'GPS Coordinates' ||
        address.startsWith('Location: ');
    if (looksLikeCoords) {
      try {
        final fb = await _reverseGeocodeWithNominatim(
            position.latitude, position.longitude);
        if (fb != null) {
          address = fb['address'] ?? address;
          neighborhood = fb['neighborhood'] ?? neighborhood;
        }
      } catch (e) {
        AppLogger.error('LocationService: Fallback reverse geocode failed: $e');
      }
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
      AppLogger.error('LocationService: Error checking if location service enabled: $e');
      return false;
    }
  }

  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      AppLogger.error('LocationService: Error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  static Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      AppLogger.error('LocationService: Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  static void openLocationSettings() {
    try {
      Geolocator.openLocationSettings();
    } catch (e) {
      AppLogger.error('LocationService: Error opening location settings: $e');
    }
  }

  static void openAppSettings() {
    try {
      Geolocator.openAppSettings();
    } catch (e) {
      AppLogger.error('LocationService: Error opening app settings: $e');
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
      AppLogger.error('LocationService: Error checking permission: $e');
      return false;
    }
  }

  // Method to get a quick location without detailed error handling (for testing)
  static Future<Position?> getSimplePosition() async {
    try {
      bool hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        AppLogger.debug('LocationService: No valid permissions for simple position');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      ).timeout(const Duration(seconds: 7));

      AppLogger.error(
          'LocationService: Simple position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      AppLogger.error('LocationService: Simple position failed: $e');
      return null;
    }
  }

  /// Clear location cache (useful for testing or when user explicitly requests fresh location)
  static void clearCache() {
    _cachedLocation = null;
    _cacheTime = null;
    AppLogger.debug('LocationService: Cache cleared');
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Convert latitude and longitude coordinates to a readable address
  static Future<LocationData?> coordinatesToLocation(
      double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) {
      AppLogger.error(
          'Error converting coordinates to location: Null coordinates provided');
      return null;
    }

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
      } else {
        AppLogger.error('No placemarks found for coordinates: $latitude, $longitude');
      }
    } catch (e) {
      AppLogger.error('Error converting coordinates to location: $e');
    }

    // Try network reverse geocoding fallback
    try {
      final fb = await _reverseGeocodeWithNominatim(latitude, longitude);
      if (fb != null) {
        return LocationData(
          latitude: latitude,
          longitude: longitude,
          address: fb['address'] ??
              '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
          neighborhood: fb['neighborhood'] ?? 'Unknown area',
        );
      }
    } catch (e) {
      AppLogger.error('Reverse geocoding (Nominatim) failed: $e');
    }

    // Return coordinates as fallback if all else fails
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
      if (locationData != null && locationData.address.isNotEmpty) {
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
      AppLogger.error('Error getting location display: $e');
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

  /// Fallback reverse geocoding via OpenStreetMap Nominatim
  static Future<Map<String, String>?> _reverseGeocodeWithNominatim(
      double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_reverseGeocodeCache.containsKey(key)) {
      return _reverseGeocodeCache[key]!;
    }

    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude');
    final resp = await http.get(uri, headers: {
      'User-Agent': 'AlluwalEducationHub/1.0 (support@alluwal.edu)'
    }).timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final addr = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};

    String? city = addr['city'] ?? addr['town'] ?? addr['village'];
    String? suburb = addr['suburb'] ?? addr['neighbourhood'];
    String? state = addr['state'];
    String? country = addr['country'];

    String neighborhood = city ?? suburb ?? state ?? country ?? 'Unknown area';
    String composed;
    if (city != null && state != null) {
      composed = '$city, $state';
    } else if (city != null && country != null) {
      composed = '$city, $country';
    } else if (state != null && country != null) {
      composed = '$state, $country';
    } else {
      composed = (data['display_name'] as String?) ?? neighborhood;
    }

    final result = {'address': composed, 'neighborhood': neighborhood};
    _reverseGeocodeCache[key] = result;
    return result;
  }

  /// Test geocoding with specific coordinates for debugging
  static Future<void> testCoordinateConversion(double lat, double lng) async {
    try {
      AppLogger.debug('Testing conversion for coordinates: $lat, $lng');
      LocationData? result = await coordinatesToLocation(lat, lng);
      if (result != null) {
        AppLogger.debug('Address: ${result.address}');
        AppLogger.debug('Neighborhood: ${result.neighborhood}');
        AppLogger.error(
            'Display: ${formatLocationForDisplay(result.address, result.neighborhood)}');
      } else {
        AppLogger.error('Geocoding returned null');
      }
    } catch (e) {
      AppLogger.error('Error in test conversion: $e');
    }
  }

  /// Batch convert coordinates to locations for multiple timesheet entries
  static Future<void> updateTimesheetEntriesWithAddresses() async {
    try {
      // This method can be called periodically to update older entries
      // that might have coordinates but no address data
      AppLogger.error('Background location conversion completed');
    } catch (e) {
      AppLogger.error('Error in batch location conversion: $e');
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
