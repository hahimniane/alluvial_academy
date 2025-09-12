# Timezone Clock-In Fix

## Problem
- Admin in Maine creates shift: 8:00 PM - 11:59 PM EST
- Teacher in Germany (using VPN) could clock in during this window
- Issue: Time validation was comparing local times instead of UTC

## Root Cause
The shift validation logic in `TeachingShift` model was using `.toLocal()` which converts UTC to the device's local timezone. This meant:
- Shift stored: 8 PM Maine = 1 AM UTC (next day)
- Teacher in Germany checks at 2 AM Germany time = 1 AM UTC
- Old code: compared 2 AM local > 8 PM local (converted) ✓ ALLOWED (wrong!)
- New code: compared 1 AM UTC > 1 AM UTC ✗ BLOCKED (correct!)

## Fix Applied
Changed all time comparisons in shift validation to use UTC:

### Before (incorrect):
```dart
bool get canClockIn {
  final now = DateTime.now();
  final shiftStartLocal = shiftStart.toLocal();  // WRONG: converts to device timezone
  final shiftEndLocal = shiftEnd.toLocal();
  return now.isAfter(clockInWindow) && now.isBefore(clockOutWindow);
}
```

### After (correct):
```dart
bool get canClockIn {
  final nowUtc = DateTime.now().toUtc();
  final shiftStartUtc = shiftStart.toUtc();  // CORRECT: compare in UTC
  final shiftEndUtc = shiftEnd.toUtc();
  return nowUtc.isAfter(clockInWindow) && nowUtc.isBefore(clockOutWindow);
}
```

## Files Changed
1. `lib/core/models/teaching_shift.dart`
   - `canClockIn` getter
   - `isCurrentlyActive` getter  
   - `hasExpired` getter

2. `lib/core/services/shift_timesheet_service.dart`
   - `getValidShiftForClockIn` method
   - Added UTC comparison logging

## How It Works Now
1. Admin creates shift in their timezone → converted to UTC for storage
2. Teacher tries to clock in → current time compared to shift time in UTC
3. Clock-in only allowed if current UTC time is within shift UTC window
4. Display still shows times in each user's local timezone

## Testing
- Create shift: 8 PM Maine time
- Try to clock in from Germany at 2 AM Germany time
- Should be blocked (outside UTC window)
- Try to clock in from Maine at 8:15 PM Maine time  
- Should be allowed (within UTC window)
