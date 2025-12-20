# Setup Android

## Download SDK

- Download the Zoom Android SDK from the [Zoom App Marketplace](https://marketplace.zoom.us/)
- Copy the file inside `mobilertc` folder and place it into the `Plugin > android > libs` folder
- Plugin location on macOS: `~/.pub-cache/hosted/pub.dev/flutter_zoom_meeting_sdk-0.0.7/android/libs`
- Example:

```bash
libs
├── buld.gradle
└── mobilertc.arr
```

<img width="340" alt="Screenshot 2025-04-30 at 3 28 36 PM" src="https://github.com/user-attachments/assets/e51fbc5f-8ba4-4cc9-93f0-8678ef68eb8f" />

*Figure 1: Downloaded Zoome Meeting Android SDK*

<img width="393" alt="Screenshot 2025-04-30 at 3 38 25 PM" src="https://github.com/user-attachments/assets/b9421339-f2c9-4aa0-ba87-8404e84b8d5e" />

*Figure 2: Place the required file inside plugin's libs folder*


## Adjust SDK `build.gradle`

1. After placing the Zoom SDK inside the `libs` folder, open the `build.gradle` file.
2. Modify the `build.gradle` to include the necessary dependencies required by the Zoom SDK. The new configuration should look like this:
   
   - Convert the original `dependencies.add` entries to the format shown below. You can safely remove other dependency entries that are not necessary.
   
   ```gradle
   ext.sdkDependenciesList = [
       "androidx.security:security-crypto:1.1.0-alpha05",
       "com.google.crypto.tink:tink-android:1.7.0",
       // Other dependencies can go here...
   ]
   ```

<img width="1512" alt="Screenshot 2025-04-30 at 3 40 56 PM" src="https://github.com/user-attachments/assets/88423ee2-3e09-430e-8488-d2f1c8f202f5" />

*Figure 3: Modify `build.gradle` to include required SDK dependencies*


## Adjust App `build.gradle.kts`

- Edit `<YourApp>/android/app/build.gradle.kts` with the following settings:

```
android {
    // ...
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true 
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = 26
    }

    // ...
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

<img width="1512" alt="Screenshot 2025-04-30 at 3 44 23 PM" src="https://github.com/user-attachments/assets/c61a4299-90e7-430e-8979-14e428e246bd" />

*Figure 4: Adjust App build.gradle.kts*

---

Now run `flutter run`, you should be able to launch without errors.

---

# Next

- [iOS Setup Instructions](./README_IOS.md)
- [macOS Setup Instructions](./README_MACOS.md)
- [Windows Setup Instructions](./README_WINDOWS.md)
- [Home](./README.md)
