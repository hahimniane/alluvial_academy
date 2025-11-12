# Clock-in Testing Guide

## Overview

Testing the clock-in functionality requires different approaches depending on what you want to test:

1. **Unit Tests** - Logic without Firebase (✅ Created)
2. **Widget Tests** - UI interaction (Requires widget testing)
3. **Integration Tests** - Full flow with Firebase (Requires Firebase Test Lab or mocking)
4. **Manual Tests** - Real device testing (Most reliable for full flow)

## Current Test Coverage

### ✅ Created: Unit Tests (No Firebase Required)
**File:** `test/features/time_clock/clock_in_workflow_test.dart`

Tests the clock-in logic without Firebase:
- Platform detection in clock-in flow
- Data validation
- Parameter structure
- State management
- Error scenarios
- Analytics tracking

**Run:**
```bash
flutter test test/features/time_clock/clock_in_workflow_test.dart
```

## Missed Shift Behaviour (Auto Detection)

- A shift is marked **missed** only after the scheduled end time **plus a grace window (max 15 minutes)** passes with no clock-in.
- The grace window is automatically **capped by the start time of the next scheduled shift** for the same teacher, so back-to-back shifts aren’t blocked.
- Grace logic lives in `TeachingShift.shouldBeMarkedAsMissed`, and the automated update is triggered by `ShiftMonitoringService.runPeriodicMonitoring()`.
- Firestore logs the effective window using the fields `clock_in_window_start`, `clock_in_window_end`, and `clock_in_grace_minutes` (reflecting any truncation).
- To manually verify, attempt to clock in just before the grace window expires; the shift should remain `scheduled` until the buffer elapses.
- When the shift window closes, the lifecycle Cloud Function assigns a final status:
  - `fullyCompleted` when worked minutes meet/beat the schedule
  - `partiallyCompleted` when there was some attendance but not the full slot
  - `missed` when no clock-in occurred

## Testing Approaches

### 1. Unit Tests (Current - No Firebase) ✅

**What's tested:**
- Platform detection logic
- Data validation before clock-in
- Parameter preparation
- State changes
- Error handling

**Limitations:**
- No actual database writes
- No real shift retrieval
- No location services

**Best for:**
- Fast feedback during development
- CI/CD pipelines
- Logic verification

### 2. Widget Tests (Recommended Next Step)

**What to test:**
- Clock-in button appears correctly
- Loading states during clock-in
- Success/error messages
- Platform-specific UI elements

**Example:**
```dart
testWidgets('should show clock-in button when shift is available', (tester) async {
  // Build the TimeClockScreen widget
  await tester.pumpWidget(MyApp());
  
  // Find clock-in button
  expect(find.text('Tap to Clock In'), findsOneWidget);
  
  // Tap the button
  await tester.tap(find.text('Tap to Clock In'));
  await tester.pump();
  
  // Verify loading state
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

**Setup required:**
- Mock Firebase services
- Mock location services
- Widget test harness

### 3. Integration Tests with Firebase Mocking

**What to test:**
- Full clock-in flow with mocked Firebase
- Database writes and reads
- Service layer integration

**Requires:**
- `fake_cloud_firestore` package
- Mock location service
- Mock auth service

**Example setup:**
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  
  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    
    // Inject mocks into services
    // This requires refactoring services to accept firestore instances
  });
  
  test('should save platform to timesheet on clock-in', () async {
    // Setup mock shift
    await firestore.collection('teaching_shifts').add({
      'id': 'shift-123',
      'teacher_id': 'teacher-456',
      'status': 'scheduled',
      // ... other fields
    });
    
    // Perform clock-in
    // ... test logic
    
    // Verify platform was saved
    final timesheets = await firestore.collection('timesheet_entries').get();
    expect(timesheets.docs.first.data()['clock_in_platform'], isNotNull);
  });
}
```

**Add to pubspec.yaml:**
```yaml
dev_dependencies:
  fake_cloud_firestore: ^2.4.0
  firebase_auth_mocks: ^0.13.0
```

### 4. Manual Testing (Most Reliable for Full Flow)

**Test Checklist:**

#### Web Testing:
```
□ Open app in Chrome
□ Login as teacher
□ Navigate to Time Clock
□ Click "Clock In"
□ Check console logs for "Clock-in platform detected: web"
□ Open Firestore Console
□ Navigate to timesheet_entries collection
□ Verify latest entry has clock_in_platform: "web"
□ Navigate to teaching_shifts collection
□ Verify shift has last_clock_in_platform: "web"
```

#### Android Testing:
```
□ Install app on Android device
□ Login as teacher
□ Navigate to Time Clock
□ Click "Clock In"
□ Check logcat for "Clock-in platform detected: android"
□ Open Firestore Console
□ Verify clock_in_platform: "android"
□ Verify last_clock_in_platform: "android"
```

#### iOS Testing:
```
□ Install app on iOS device
□ Login as teacher
□ Navigate to Time Clock
□ Click "Clock In"
□ Check Xcode console for "Clock-in platform detected: ios"
□ Open Firestore Console
□ Verify clock_in_platform: "ios"
□ Verify last_clock_in_platform: "ios"
```

## Testing with Firebase Test Lab

Firebase Test Lab allows you to run tests on real devices in the cloud:

```bash
# Build test APK
flutter build apk --debug

# Build test instrumentation APK
cd android
./gradlew app:assembleAndroidTest
./gradlew app:assembleDebug -Ptarget=integration_test/app_test.dart

# Run on Test Lab
gcloud firebase test android run \
  --type instrumentation \
  --app build/app/outputs/apk/debug/app-debug.apk \
  --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
  --device model=Pixel2,version=28,locale=en,orientation=portrait
```

## Debugging Clock-in Issues

### Check Console Logs

**Look for these log messages:**

1. Platform detection:
```
Clock-in platform detected: web
```

2. Service call:
```
ShiftTimesheetService: Starting clock-in process for shift shift-123
```

3. Platform recording:
```
ShiftService: Recording clock-in platform: web
```

### Verify Firestore Data

**Check timesheet_entries:**
```javascript
{
  teacher_id: "teacher-123",
  shift_id: "shift-456",
  clock_in_platform: "web",  // ← Should be present
  clock_in_timestamp: Timestamp,
  // ... other fields
}
```

**Check teaching_shifts:**
```javascript
{
  id: "shift-456",
  teacher_id: "teacher-123",
  last_clock_in_platform: "web",  // ← Should be present
  status: "active",
  // ... other fields
}
```

## Running Current Tests

### Run all clock-in workflow tests:
```bash
flutter test test/features/time_clock/clock_in_workflow_test.dart
```

### Run with verbose output:
```bash
flutter test test/features/time_clock/clock_in_workflow_test.dart --reporter=expanded
```

### Run specific test:
```bash
flutter test test/features/time_clock/clock_in_workflow_test.dart --name "should detect platform before clock-in"
```

## Next Steps to Improve Testing

### 1. Add Firebase Mocking (Recommended)

**Install dependencies:**
```bash
flutter pub add --dev fake_cloud_firestore firebase_auth_mocks
```

**Refactor services to be testable:**
```dart
// Before (hardcoded)
class ShiftService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
}

// After (injectable)
class ShiftService {
  final FirebaseFirestore firestore;
  
  ShiftService({FirebaseFirestore? firestore}) 
    : firestore = firestore ?? FirebaseFirestore.instance;
}
```

### 2. Add Widget Tests

Create `test/features/time_clock/time_clock_screen_test.dart`:
```dart
testWidgets('clock-in button shows platform', (tester) async {
  // Test clock-in button UI
});
```

### 3. Add Integration Tests

Create `integration_test/clock_in_test.dart`:
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('full clock-in flow', (tester) async {
    // Test complete flow on real device
  });
}
```

### 4. Set up CI/CD Testing

**GitHub Actions example:**
```yaml
name: Test Clock-in
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter test test/features/time_clock/
```

## Test Data Setup

For manual testing, ensure you have:

1. **Test teacher account:**
   - Email: teacher@test.com
   - Password: test123
   - User type: teacher

2. **Test shift:**
   - Teacher: Above teacher
   - Status: scheduled
   - Time: Current time or near future

3. **Firebase Rules:** Ensure test account has permissions

## Common Issues and Solutions

### Issue: Platform not being saved

**Check:**
1. Platform detection works: `PlatformUtils.detectPlatform()`
2. Parameter is passed: Check console logs
3. Service receives it: Check ShiftTimesheetService logs
4. Firestore rules allow write

**Solution:**
```dart
// Add debug logs
final platform = PlatformUtils.detectPlatform();
print('DEBUG: Platform = $platform');

await ShiftTimesheetService.clockInToShift(
  userId,
  shiftId,
  location: location,
  platform: platform,  // Make sure this is passed
);
```

### Issue: Tests timeout

**Solution:**
```bash
# Increase timeout
flutter test --timeout=60s test/features/time_clock/
```

### Issue: Widget tests can't find Firebase

**Solution:**
```dart
TestWidgetsFlutterBinding.ensureInitialized();
setupFirebaseAuthMocks();  // From firebase_auth_mocks
```

## Best Practices

1. **Start with unit tests** - Fast feedback
2. **Add widget tests** - Verify UI logic
3. **Manual test on real devices** - Most reliable for Firebase
4. **Use Test Lab for CI/CD** - Automate device testing
5. **Monitor production** - Use Firebase Analytics to verify

## Resources

- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [Firebase Test Lab](https://firebase.google.com/docs/test-lab)
- [Widget Testing](https://docs.flutter.dev/cookbook/testing/widget)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)

