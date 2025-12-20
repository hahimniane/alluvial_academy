# Platform Tracking Implementation

## Overview
This document describes the implementation of platform tracking for teacher clock-ins. The system now records which platform (web, Android, iOS) was used when a teacher clocks into a shift.

## Implementation Date
November 10, 2025

## Changes Made

### 1. New Utility File: `lib/core/utils/platform_utils.dart`
Created a platform detection utility that provides:
- `detectPlatform()` - Returns 'web', 'android', 'ios', 'macos', 'windows', 'linux', or 'fuchsia'
- `getPlatformDisplayName()` - Returns human-readable platform names
- `isMobile()` - Check if running on mobile platforms
- `isDesktop()` - Check if running on desktop platforms

### 2. Updated `TeachingShift` Model
**File:** `lib/core/models/teaching_shift.dart`

Added new field:
```dart
final String? lastClockInPlatform; // Platform used for last clock-in (web, android, ios)
```

Updated methods:
- Constructor: Added `lastClockInPlatform` parameter
- `toFirestore()`: Saves platform to Firestore as `'last_clock_in_platform'`
- `fromFirestore()`: Reads platform from Firestore
- `copyWith()`: Supports updating platform field

### 3. Updated `ShiftTimesheetService`
**File:** `lib/core/services/shift_timesheet_service.dart`

Changes:
- `clockInToShift()`: Added optional `platform` parameter
- `_createTimesheetEntryFromShift()`: Added optional `platform` parameter
- Timesheet entry now includes `'clock_in_platform'` field in Firestore

### 4. Updated `ShiftService`
**File:** `lib/core/services/shift_service.dart`

Changes:
- `clockIn()`: Added optional `platform` parameter
- Stores platform as `'last_clock_in_platform'` on shift document when provided
- Logs platform information for debugging

### 5. Updated Time Clock Screen
**File:** `lib/features/time_clock/screens/time_clock_screen.dart`

Changes:
- Added import for `platform_utils.dart`
- Detects platform before clock-in using `PlatformUtils.detectPlatform()`
- Passes platform to `ShiftTimesheetService.clockInToShift()`
- Logs detected platform for debugging

## Database Schema

### Firestore Collection: `timesheet_entries`
New field added:
```
clock_in_platform: string ('web', 'android', 'ios', etc.)
```

### Firestore Collection: `teaching_shifts`
New field added:
```
last_clock_in_platform: string ('web', 'android', 'ios', etc.)
```

## Usage Examples

### Querying timesheet entries by platform
```dart
final webClockIns = await FirebaseFirestore.instance
  .collection('timesheet_entries')
  .where('clock_in_platform', isEqualTo: 'web')
  .get();
```

### Checking shift's last clock-in platform
```dart
final shift = TeachingShift.fromFirestore(doc);
print('Last clocked in from: ${shift.lastClockInPlatform ?? 'Unknown'}');
```

### Getting platform display name
```dart
final platformName = PlatformUtils.getPlatformDisplayName();
// Returns: "Web Browser", "Android", "iOS", etc.
```

## Benefits

1. **Analytics**: Track which platforms teachers prefer for clocking in
2. **Troubleshooting**: Identify platform-specific issues with clock-in/out
3. **Compliance**: Maintain audit trail of device types used
4. **User Experience**: Optimize UX for most-used platforms

## Testing Recommendations

1. Test clock-in from web browser - verify `clock_in_platform: 'web'`
2. Test clock-in from Android device - verify `clock_in_platform: 'android'`
3. Test clock-in from iOS device - verify `clock_in_platform: 'ios'`
4. Verify platform information appears in both:
   - `timesheet_entries` collection (for each clock-in event)
   - `teaching_shifts` collection (last clock-in platform)

## Backward Compatibility

- All new fields are optional (`String?`)
- Existing data without platform information will show as `null`
- System gracefully handles missing platform data
- No migration required for existing records

## Future Enhancements

Potential improvements:
- Add platform breakdown in admin analytics dashboard
- Show platform icons in timesheet views
- Filter timesheet entries by platform
- Track platform trends over time
- Alert if unusual platform usage detected

