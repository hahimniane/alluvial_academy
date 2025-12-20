# Test Suite Documentation

## Platform Tracking Tests

This directory contains comprehensive unit and integration tests for the platform tracking feature.

## Test Files

### 1. `core/utils/platform_utils_test.dart`
Unit tests for the `PlatformUtils` class:
- Platform detection across different platforms (web, Android, iOS, etc.)
- Display name mapping
- Mobile/desktop detection
- Consistency checks
- Error handling

**Run command:**
```bash
flutter test test/core/utils/platform_utils_test.dart
```

### 2. `core/models/teaching_shift_test.dart`
Unit tests for platform tracking in the `TeachingShift` model:
- Constructor behavior with platform field
- Serialization to Firestore (toFirestore)
- Deserialization from Firestore (fromFirestore)
- copyWith functionality
- Round-trip serialization
- Integration scenarios (clock-in/out with platform tracking)

**Run command:**
```bash
flutter test test/core/models/teaching_shift_test.dart
```

### 3. `core/services/platform_tracking_integration_test.dart`
Integration tests for the complete platform tracking workflow:
- End-to-end clock-in flow with platform detection
- Platform validation
- Display name mapping
- Platform-specific behavior (web, mobile, desktop)
- Error handling and edge cases
- Real-world scenarios (analytics, filtering, troubleshooting)
- Performance tests

**Run command:**
```bash
flutter test test/core/services/platform_tracking_integration_test.dart
```

## Running All Tests

### Run all platform tracking tests
```bash
flutter test test/core/
```

### Run all tests in the project
```bash
flutter test
```

### Run tests with coverage
```bash
flutter test --coverage
```

### Run tests on specific platform
```bash
# Web
flutter test -d chrome

# Android (requires device/emulator)
flutter test -d android

# iOS (requires device/simulator)
flutter test -d ios
```

## Test Coverage

The test suite covers:

- ✅ Platform detection logic (web, Android, iOS, macOS, Windows, Linux)
- ✅ Display name mapping
- ✅ Mobile/desktop classification
- ✅ TeachingShift model integration
- ✅ Firestore serialization/deserialization
- ✅ copyWith functionality
- ✅ Error handling
- ✅ Data integrity
- ✅ Performance
- ✅ Real-world scenarios

## Test Organization

```
test/
├── core/
│   ├── models/
│   │   └── teaching_shift_test.dart      # Model tests
│   ├── services/
│   │   └── platform_tracking_integration_test.dart  # Integration tests
│   └── utils/
│       └── platform_utils_test.dart      # Utility tests
├── widget_test.dart                      # Widget tests
└── README.md                             # This file
```

## Writing New Tests

When adding new platform-related features:

1. Add unit tests to the appropriate file
2. Add integration tests if the feature spans multiple components
3. Test on all supported platforms (web, Android, iOS)
4. Ensure tests pass both locally and in CI/CD

## Common Test Patterns

### Testing Platform Detection
```dart
test('should detect correct platform', () {
  final platform = PlatformUtils.detectPlatform();
  expect(platform, isIn(['web', 'android', 'ios', 'macos', 'windows', 'linux']));
});
```

### Testing Model Serialization
```dart
test('should serialize platform to Firestore', () {
  final shift = testShift.copyWith(lastClockInPlatform: 'web');
  final data = shift.toFirestore();
  expect(data['last_clock_in_platform'], 'web');
});
```

### Testing Error Handling
```dart
test('should handle errors gracefully', () {
  expect(() => PlatformUtils.detectPlatform(), returnsNormally);
});
```

## Continuous Integration

These tests are designed to run in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: flutter test --coverage

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage/lcov.info
```

## Troubleshooting

### Tests fail on specific platform
- Ensure the platform-specific dependencies are installed
- Check that the test environment matches the target platform
- Review platform-specific test expectations

### Coverage not generated
- Run: `flutter test --coverage`
- Check that `lcov` is installed on your system
- Review the coverage report at `coverage/lcov.info`

### Tests timeout
- Increase timeout: `flutter test --timeout=60s`
- Check for infinite loops or blocking operations
- Review async test handling

## Best Practices

1. **Isolation**: Each test should be independent
2. **Clarity**: Test names should describe what they test
3. **Coverage**: Aim for >80% code coverage
4. **Speed**: Tests should run quickly (< 30s for full suite)
5. **Reliability**: Tests should not be flaky
6. **Documentation**: Document complex test scenarios

## Related Documentation

- [Platform Tracking Implementation](../PLATFORM_TRACKING_IMPLEMENTATION.md)
- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [Test-Driven Development](https://flutter.dev/docs/cookbook/testing)

