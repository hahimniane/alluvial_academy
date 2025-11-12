# Timezone Auto-Logout and Timesheet Display Fix

## Issues Fixed

### 1. Clock-In Window (✓ Already working correctly)
- Teachers can clock in 15 minutes before shift start
- Fixed in previous update: using UTC comparison in `canClockIn` getter

### 2. Auto-Logout Timing (✓ Fixed)
- System now automatically clocks out teachers 15 minutes after shift end
- Fixed `clockOutDeadline` getter to use UTC
- Updated auto-logout timers in both clock screens to use UTC comparison

### 3. Timesheet Display (✓ Fixed)
- Timesheet was showing UTC times instead of local times
- Fixed auto-logout to format time in local timezone for display

## Technical Changes

### 1. TeachingShift Model (`lib/core/models/teaching_shift.dart`)
```dart
// Before: Used .toLocal() causing timezone issues
DateTime get clockOutDeadline {
  return shiftEnd.toLocal().add(const Duration(minutes: 15));
}

// After: Uses UTC for consistency
DateTime get clockOutDeadline {
  return shiftEnd.toUtc().add(const Duration(minutes: 15));
}
```

### 2. Auto-Logout Timer (`lib/features/time_clock/screens/`)
```dart
// Before: Compared local times
final now = DateTime.now();
if (now.isAfter(autoLogoutTime)) { ... }

// After: Compares UTC times
final nowUtc = DateTime.now().toUtc();
if (nowUtc.isAfter(autoLogoutTimeUtc)) { ... }
```

### 3. Timesheet Display (`lib/core/services/shift_timesheet_service.dart`)
```dart
// Before: Formatted UTC time directly
final endTime = DateFormat('h:mm a').format(autoClockOutTime);

// After: Converts UTC to local before formatting
final autoClockOutTimeLocal = autoClockOutTimeUtc.toLocal();
final endTime = DateFormat('h:mm a').format(autoClockOutTimeLocal);
```

## How It Works Now

1. **Clock-In**: 
   - Allowed from 15 minutes before shift start (UTC comparison)
   - Times displayed in teacher's local timezone

2. **Auto-Logout**:
   - Triggers 15 minutes after shift end (UTC comparison)
   - Saves clock-out time in teacher's local timezone for display

3. **Timesheet**:
   - Shows all times in the user's local timezone
   - Maintains UTC internally for accurate comparisons

## Testing Scenarios

1. **Maine Admin creates shift**: 8:00 PM - 11:00 PM EST
2. **Teacher can clock in**: 7:45 PM - 11:15 PM EST
3. **Auto-logout happens**: 11:15 PM EST (if not manually clocked out)
4. **Timesheet shows**: Correct local times for both locations
