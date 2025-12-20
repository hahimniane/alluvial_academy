# Setup iOS

## 1. Download SDK

- Download the Zoom iOS SDK from the [Zoom App Marketplace](https://marketplace.zoom.us/)
- Create a `ZoomSDK/ios/` folder and extract the SDK contents into it.
- We only need `MobileRTC.xcframework` and `MobileRTCResources.bundle`

**Example Directory Structure:**

```bash
<YourApp>/
├── ios/
├── ...
└── ZoomSDK/
    └── ios/
        ├── MobileRTC.xcframework
        └── MobileRTCResources.bundle
```

<img width="415" alt="Screenshot 2025-04-30 at 2 58 41 PM" src="https://github.com/user-attachments/assets/fb01c84f-47f7-4b1c-ab46-0ffd92ddfd09" />

*Figure: Download and extract the Zoom SDK into your project*

---

## 2. Configure In Xcode


First, make sure to run pod install to generate the Pod targets:
```bash
cd ios
pod install
```

Then, open the ios project in Xcode:

```bash
<YourApp>/ios
```

> This will allow you to access both your app target and the plugin target in Xcode.

<img width="630" alt="Screenshot 2025-04-30 at 2 35 52 PM" src="https://github.com/user-attachments/assets/036dac34-a6b9-4c95-a1bc-acc7a060437c" />

*Figure: Open the iOS project with Xcode*

### 2.1 Runner Target Configuration

#### General
  1. **Frameworks, Libraries, and Embedded Content**
     ```bash
     Add MobileRTC.xcframework
     ```
  
<img width="1512" alt="Screenshot 2025-04-30 at 2 31 53 PM" src="https://github.com/user-attachments/assets/4134a17f-bba6-4954-967a-d089767d4a47" />

*Figure: Add MobileRTC.xcframework in (Frameworks, Libraries, and Embedded Content)*

#### Signing & Capabilities
  1. Choose your **Team**

#### Build Phases
  1. **Link Binary With Libraries**
     ```bash
     Add MobileRTC.xcframework
     ```

  2. **Copy Bundle Resources**
     ```bash
     Add MobileRTCResources.bundle
     ```
        
  3. **Embed Frameworks**
     ```bash
     Add MobileRTC.xcframework
     ```
  
<img width="1512" alt="Screenshot 2025-04-30 at 2 32 24 PM" src="https://github.com/user-attachments/assets/3074841f-d73d-4eda-900d-254d1f1e996e" />

*Figure: Add MobileRTC.xcframework and MobileRTCResources.bundle in (Build Phases)*

---

### 2.2 Plugin Pod Configuration

#### Pods > flutter_zoom_meeting_sdk > General > Frameworks and Libraries
  - Add `MobileRTC.xcframework`
  - Set **Embed** to **Do Not Embed**

<img width="1512" alt="Screenshot 2025-04-30 at 2 32 35 PM" src="https://github.com/user-attachments/assets/7bf497a8-7af5-451d-a7d8-7562a286c5b7" />

*Figure: Set MobileRTC.xcframework in plugin target*

> ✅ This allows the plugin to correctly read and use the Zoom SDK.

---

## 3. Add Permissions to Info.plist

Edit `<YourApp>/ios/Runner/Info.plist` and add the following keys:

```bash
<key>NSBluetoothPeripheralUsageDescription</key>
<string>We will use your Bluetooth to access your Bluetooth headphones.</string>
<key>NSCameraUsageDescription</key>
<string>For people to see you during meetings, we need access to your camera.</string>
<key>NSMicrophoneUsageDescription</key>
<string>For people to hear you during meetings, we need access to your microphone.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>For people to share, we need access to your photos.</string>
```

---

## 4. Run the App

After setup, run your Flutter app, you should be able to launch without errors:

```bash
flutter run
```


> ⚠️ If you see the following error:
> ```bash
> Swift Compiler Error (Xcode): No such module 'MobileRTC'
> ```
> This usually happens because Flutter ran `pod install` automatically, which resets your plugin's Pod configuration.
>
> ✅ To fix this, reapply the Pod target configuration:
> - Go to `Pods > flutter_zoom_meeting_sdk` in Xcode
> - Add `MobileRTC.xcframework` under **Frameworks, Libraries, and Embedded Content**
> - Set **Embed** to **Do Not Embed**
>
> Next run flutter again, you should be able to launch without errors.

---

# Next

- [Android Setup Instructions](./README_ANDROID.md)
- [macOS Setup Instructions](./README_MACOS.md)
- [Windows Setup Instructions](./README_WINDOWS.md)
- [Home](./README.md)
