# Types of Tests in Flutter

## Overview

Beyond unit tests, there are several other types of tests, each serving a different purpose:

```
Unit Tests ────────→ Test individual functions/classes (fastest)
Widget Tests ──────→ Test UI components and interactions
Integration Tests ─→ Test complete features/flows
E2E Tests ─────────→ Test entire app on real devices (slowest)
```

## 1. Unit Tests ✅ (Already Created)

**What:** Test individual functions, classes, and logic in isolation

**Example:** Testing platform detection
```dart
test('should detect platform', () {
  final platform = PlatformUtils.detectPlatform();
  expect(platform, isNotNull);
});
```

**Characteristics:**
- ⚡ Very fast (milliseconds)
- 🔧 No dependencies (no Firebase, no UI)
- 🎯 Tests one thing at a time
- 🔄 Easy to debug

**Run:**
```bash
flutter test test/core/utils/platform_utils_test.dart
```

---

## 2. Widget Tests (UI Component Tests)

**What:** Test Flutter widgets, UI interactions, and rendering

**Purpose:** Verify UI components work correctly without running on a real device

**Example:** Testing clock-in button
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('should show clock-in button', (WidgetTester tester) async {
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockScreen(),
      ),
    );
    
    // Find the button
    expect(find.text('Clock In'), findsOneWidget);
    
    // Tap the button
    await tester.tap(find.text('Clock In'));
    await tester.pump(); // Rebuild widget
    
    // Verify loading indicator appears
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  
  testWidgets('should display platform in debug mode', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TimeClockScreen()));
    
    // Verify platform text is shown
    final platform = PlatformUtils.detectPlatform();
    expect(find.textContaining(platform), findsWidgets);
  });
  
  testWidgets('clock-in button disabled when no shift', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TimeClockScreen()));
    
    // Find button
    final button = find.byType(ElevatedButton);
    final widget = tester.widget<ElevatedButton>(button);
    
    // Verify it's disabled
    expect(widget.onPressed, isNull);
  });
}
```

**What Widget Tests Can Do:**
- ✅ Find widgets by type, text, key
- ✅ Tap, drag, scroll interactions
- ✅ Verify widget properties
- ✅ Test animations
- ✅ Test form validation
- ✅ Test navigation
- ✅ Mock dependencies

**Characteristics:**
- ⚡ Fast (seconds)
- 🎨 Tests UI without device
- 🔧 Can mock services
- 📱 Simulates user interactions

**Create File:**
```bash
test/features/time_clock/time_clock_screen_widget_test.dart
```

**Run:**
```bash
flutter test test/features/time_clock/time_clock_screen_widget_test.dart
```

---

## 3. Integration Tests (Feature Tests)

**What:** Test complete features or workflows with real services

**Purpose:** Test how multiple components work together

**Example:** Testing full clock-in flow with Firebase
```dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Clock-in Integration Tests', () {
    testWidgets('complete clock-in flow', (tester) async {
      // Start app
      app.main();
      await tester.pumpAndSettle();
      
      // Login
      await tester.enterText(find.byType(TextField).first, 'teacher@test.com');
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Navigate to Time Clock
      await tester.tap(find.text('Time Clock'));
      await tester.pumpAndSettle();
      
      // Click Clock In
      await tester.tap(find.text('Clock In'));
      await tester.pumpAndSettle(Duration(seconds: 5));
      
      // Verify success message
      expect(find.text('Clocked in successfully'), findsOneWidget);
      
      // Verify in Firestore (optional)
      final firestore = FirebaseFirestore.instance;
      final entry = await firestore
          .collection('timesheet_entries')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();
      
      expect(entry.docs.first.data()['clock_in_platform'], isNotNull);
    });
  });
}
```

**Characteristics:**
- 🐌 Slower (minutes)
- 🔗 Uses real Firebase
- 📱 Runs on devices/emulators
- 🎯 Tests complete flows

**Setup Required:**
```yaml
# pubspec.yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

**Create File:**
```bash
integration_test/clock_in_test.dart
```

**Run:**
```bash
# On connected device
flutter test integration_test/clock_in_test.dart

# On web
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/clock_in_test.dart -d chrome
```

---

## 4. End-to-End (E2E) Tests

**What:** Test the entire application from user perspective on real devices

**Purpose:** Verify complete user journeys work in production-like environment

**Tools:**
- **Appium** - Cross-platform
- **Detox** (for React Native, but can work with Flutter)
- **Flutter Driver** - Flutter's built-in E2E testing
- **Patrol** - Modern alternative to Flutter Driver

**Example with Flutter Driver:**
```dart
// test_driver/app.dart
import 'package:flutter_driver/driver_extension.dart';
import 'package:alluwalacademyadmin/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}

// test_driver/app_test.dart
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Clock-in E2E Test', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    test('user can clock in from web', () async {
      // Wait for app to load
      await driver.waitFor(find.byType('TextField'));
      
      // Login
      await driver.tap(find.byValueKey('email_field'));
      await driver.enterText('teacher@test.com');
      await driver.tap(find.byValueKey('password_field'));
      await driver.enterText('password123');
      await driver.tap(find.byValueKey('login_button'));
      
      // Navigate to time clock
      await driver.waitFor(find.text('Time Clock'));
      await driver.tap(find.text('Time Clock'));
      
      // Clock in
      await driver.waitFor(find.text('Clock In'));
      await driver.tap(find.text('Clock In'));
      
      // Verify success
      await driver.waitFor(find.text('Clocked in successfully'));
    });
  });
}
```

**Characteristics:**
- 🐌🐌 Slowest (minutes to hours)
- 📱 Runs on real devices
- 🌐 Tests across platforms
- 💰 Most expensive to maintain

**Run:**
```bash
flutter drive --target=test_driver/app.dart
```

---

## 5. Golden Tests (Screenshot/Visual Tests)

**What:** Compare widget screenshots to reference images

**Purpose:** Catch visual regressions

**Example:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  testGoldens('clock-in button looks correct', (tester) async {
    await tester.pumpWidgetBuilder(
      ClockInButton(enabled: true),
    );
    
    await screenMatchesGolden(tester, 'clock_in_button_enabled');
  });
  
  testGoldens('clock-in button disabled state', (tester) async {
    await tester.pumpWidgetBuilder(
      ClockInButton(enabled: false),
    );
    
    await screenMatchesGolden(tester, 'clock_in_button_disabled');
  });
}
```

**Run:**
```bash
flutter test --update-goldens  # Generate reference images
flutter test                    # Compare against references
```

---

## 6. Performance Tests

**What:** Measure app performance metrics

**Purpose:** Ensure app meets performance requirements

**Example:**
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('platform detection is fast', () {
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < 1000; i++) {
      PlatformUtils.detectPlatform();
    }
    
    stopwatch.stop();
    
    // Should complete 1000 calls in < 100ms
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });
  
  testWidgets('clock-in renders in < 16ms', (tester) async {
    await tester.pumpWidget(TimeClockScreen());
    
    // Measure frame time
    final frames = await tester.binding.framePolicy;
    expect(frames, lessThan(16)); // 60fps = 16ms per frame
  });
}
```

---

## 7. Smoke Tests (Sanity Tests)

**What:** Quick tests to verify basic functionality

**Purpose:** Fast validation that nothing is broken

**Example:**
```dart
void main() {
  group('Smoke Tests', () {
    test('app starts without crashing', () {
      expect(() => MyApp(), returnsNormally);
    });
    
    test('all services initialize', () {
      expect(() => PlatformUtils.detectPlatform(), returnsNormally);
      expect(() => FirebaseFirestore.instance, returnsNormally);
    });
    
    test('critical features accessible', () async {
      // Verify clock-in service exists
      expect(ShiftTimesheetService.clockInToShift, isNotNull);
    });
  });
}
```

---

## 8. Regression Tests

**What:** Tests that verify previously fixed bugs don't reappear

**Purpose:** Prevent old bugs from coming back

**Example:**
```dart
group('Regression Tests', () {
  test('BUG-123: platform should not be null after clock-in', () {
    // This was a bug - platform was null sometimes
    final platform = PlatformUtils.detectPlatform();
    expect(platform, isNotNull);
    expect(platform, isNotEmpty);
  });
  
  test('BUG-456: multiple clock-ins should update platform', () {
    // Bug: second clock-in didn't update platform
    final shift = testShift.copyWith(lastClockInPlatform: 'web');
    final updated = shift.copyWith(lastClockInPlatform: 'android');
    expect(updated.lastClockInPlatform, 'android');
  });
});
```

---

## Comparison Table

| Test Type | Speed | Cost | When to Use |
|-----------|-------|------|-------------|
| **Unit** | ⚡⚡⚡ Fast | 💰 Low | Always - test logic |
| **Widget** | ⚡⚡ Medium | 💰💰 Medium | Test UI components |
| **Integration** | ⚡ Slow | 💰💰💰 High | Test feature flows |
| **E2E** | 🐌 Very Slow | 💰💰💰💰 Very High | Critical user journeys |
| **Golden** | ⚡⚡ Medium | 💰💰 Medium | Visual consistency |
| **Performance** | ⚡⚡ Medium | 💰 Low | Speed requirements |
| **Smoke** | ⚡⚡⚡ Fast | 💰 Low | Quick validation |
| **Regression** | ⚡⚡⚡ Fast | 💰 Low | After bug fixes |

---

## Test Pyramid Strategy

```
        /\         E2E Tests (5-10%)
       /  \        Few, expensive, slow
      /    \       
     /------\      Integration Tests (20%)
    /        \     More, test features
   /          \    
  /------------\   Widget Tests (30%)
 /              \  Test UI components
/________________\ Unit Tests (40-50%)
                   Many, cheap, fast
```

**Recommended Distribution:**
- 40-50% Unit Tests
- 30% Widget Tests
- 20% Integration Tests
- 5-10% E2E Tests

---

## For Your Clock-in Feature

### ✅ Already Have: Unit Tests
```bash
flutter test test/core/
flutter test test/features/time_clock/clock_in_workflow_test.dart
```

### 🎯 Recommended Next: Widget Tests
Test the Time Clock screen UI:
```dart
testWidgets('clock-in button appears when shift available', (tester) async {
  // Test UI
});
```

### 🚀 Then: Integration Tests
Test complete clock-in with Firebase:
```dart
testWidgets('full clock-in saves platform to database', (tester) async {
  // Test complete flow
});
```

### 🎁 Optional: E2E Tests
Test on real devices across platforms:
```bash
flutter drive --target=test_driver/clock_in_e2e.dart
```

---

## Quick Start Guide

### 1. Add Widget Test (5 minutes)
```dart
// test/features/time_clock/time_clock_screen_widget_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget test', (tester) async {
    // Your test here
  });
}
```

### 2. Add Integration Test (15 minutes)
```yaml
# pubspec.yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

```dart
// integration_test/clock_in_test.dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Your integration tests
}
```

### 3. Run Different Test Types
```bash
# Unit tests (fast)
flutter test test/core/

# Widget tests (medium)
flutter test test/features/

# Integration tests (slow)
flutter test integration_test/

# E2E tests (very slow)
flutter drive --target=test_driver/app.dart
```

---

## Best Practices

1. **Start with Unit Tests** - Cheapest, fastest feedback
2. **Add Widget Tests** - Test UI without devices
3. **Add Integration Tests** - For critical flows
4. **Add E2E Tests** - Only for most important journeys
5. **Run in CI/CD** - Automate all test types
6. **Monitor in Production** - Use Firebase Analytics

---

## Resources

- [Flutter Testing Docs](https://docs.flutter.dev/testing)
- [Widget Testing](https://docs.flutter.dev/cookbook/testing/widget)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Golden Toolkit](https://pub.dev/packages/golden_toolkit)
- [Patrol Testing](https://pub.dev/packages/patrol)

