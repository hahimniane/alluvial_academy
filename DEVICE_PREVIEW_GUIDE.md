# Device Preview Guide

## What is Device Preview?

Device Preview is a Flutter package that allows you to test your app on multiple device sizes, orientations, and configurations without needing to download all the simulators/emulators.

## Installation ✅

Already installed! The package is configured to run **ONLY in debug mode** (developer mode).

## How to Use

### 1. Run Your App in Debug Mode

```bash
flutter run
```

When you run your app in **debug mode**, you'll see a device preview toolbar around your app.

### 2. Device Preview Features

The toolbar provides:

#### 📱 **Device Selection**
- iPhone (various models: iPhone 13, 14, 15, SE, etc.)
- iPad (various sizes)
- Android phones (Pixel, Samsung, etc.)
- Android tablets
- Custom device sizes

#### 🔄 **Orientation**
- Portrait
- Landscape
- Switch instantly to test responsive design

#### 🌍 **Locale Testing**
- Test different languages
- See how text wraps in different locales

#### ♿ **Accessibility**
- Text scaling (small, normal, large, extra large)
- Bold text toggle
- Test accessibility features

#### 🌙 **Theme**
- Light mode
- Dark mode
- System theme

#### 📸 **Screenshots**
- Take screenshots of different devices
- Great for app store listings!

### 3. When Does It Appear?

- ✅ **Debug Mode**: Device Preview toolbar is visible
- ❌ **Release Mode**: Device Preview is disabled (no performance impact)
- ❌ **Production**: Device Preview is completely excluded

### 4. Using the Toolbar

1. **Device Selector** (top left): Click to change device
2. **Orientation** (top right): Rotate device
3. **Settings** (gear icon): Access all features
4. **Close** (X icon): Hide toolbar temporarily

### 5. Keyboard Shortcuts

- `d` - Toggle device frame
- `r` - Rotate device
- `s` - Take screenshot
- `f` - Toggle frame visibility

## Testing Workflow

### Example 1: Test Mobile Layouts
1. Run `flutter run`
2. Select "iPhone 15" from device selector
3. Test your teacher dashboard
4. Switch to "Galaxy S23" to compare Android
5. Rotate to landscape to test orientation

### Example 2: Test Tablet Layouts
1. Select "iPad Pro 12.9"
2. See how your forms screen looks on tablet
3. Compare with "Galaxy Tab S8"

### Example 3: Test Text Scaling
1. Click settings (gear icon)
2. Go to "Accessibility"
3. Increase text scale to 2.0x
4. Verify all text is readable and doesn't overflow

### Example 4: Test Different Screens Quickly
1. Select "iPhone SE" (smallest iPhone)
2. Navigate to timesheet
3. Verify no overflow errors
4. Switch to "iPhone 15 Pro Max" (largest)
5. Confirm layout scales properly

## Tips & Best Practices

### ✅ Do's
- Test on smallest device first (iPhone SE, small Android)
- Always check both portrait and landscape
- Test with max text scale for accessibility
- Use screenshots for bug reports

### ❌ Don'ts
- Don't use in release builds (it's auto-disabled)
- Don't rely only on preview - test on real devices too
- Don't forget to test on web separately

## Disabling Device Preview

If you want to temporarily disable Device Preview even in debug mode:

In `lib/main.dart`, change:
```dart
DevicePreview(
  enabled: kDebugMode, // ← Change this
  builder: (context) => const MyApp(),
)
```

To:
```dart
DevicePreview(
  enabled: false, // ← Disabled
  builder: (context) => const MyApp(),
)
```

## Common Issues

### Issue 1: "I don't see the toolbar"
- **Solution**: Make sure you're running in debug mode, not release mode
- Command: `flutter run` (not `flutter run --release`)

### Issue 2: "App looks different on real device"
- **Solution**: Device Preview is an approximation. Always test on real devices for final validation

### Issue 3: "Performance is slow"
- **Solution**: This is normal in debug mode. Run `flutter run --release` for production performance

## Benefits for Your Project

1. **Time Saver**: No need to download 20+ simulators
2. **Quick Testing**: Switch devices in seconds
3. **Accessibility**: Easy to test text scaling and accessibility features
4. **Screenshots**: Generate app store screenshots quickly
5. **Bug Reports**: Show exact device where bug occurs

## Example Use Cases for Your App

### Timesheet Testing
```
1. Select "iPhone SE" → Verify timesheet cards fit
2. Rotate to landscape → Check filters still work
3. Select "iPad Pro" → See desktop-like layout
4. Increase text scale → Verify no overflow
```

### Forms Testing
```
1. Select "Galaxy S23" → Test form filling
2. Switch to "Pixel 7" → Compare input styles
3. Test on "iPad Air" → See larger screen layout
```

### Dashboard Testing
```
1. Select "iPhone 13" → Check teacher dashboard
2. Rotate → Verify landscape layout
3. Increase font → Check stat cards
4. Test dark mode → Verify colors
```

## Documentation

Full documentation: https://pub.dev/packages/device_preview

---

**Remember**: Device Preview runs ONLY in debug mode and has zero impact on your production app! 🚀

