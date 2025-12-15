# Setup Windows

## 1. Download the Zoom SDK

- Download the Zoom Windows SDK from the [Zoom App Marketplace](https://marketplace.zoom.us/)
- Create a folder and place the SDK contents inside it.

**Example Directory Structure:**

```
<YourApp>/
├── windows/
├── ...
└── ZoomSDK/
    └── windows/
        ├── bin/
        │   └── ...
        ├── h/
        │   └── ...
        └── lib/
            └── ...
```

## 2. Update CMakeLists.txt

Open `<YourApp>/windows/runner/CMakeLists.txt`, and add the following at the **bottom** of the file:

```txt
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_SOURCE_DIR}/../ZoomSDK/windows/bin"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>"
)
```

> This ensures the Zoom SDK DLLs are copied to the app's output directory after the build.

## 3. Configure Zoom SDK Path

The plugin must know where to find the Zoom SDK. You can configure this path using one of the following methods:

### Option 1: Environment Variable

Set the `ZOOM_SDK_PATH` environment variable:

```bash
set ZOOM_SDK_PATH=C:\path\to\your\ZoomSDK\windows
```

### Option 2: CMake Variable

Set the SDK path when configuring your build:

```bash
cmake -DZOOM_SDK_DIR=C:/path/to/your/ZoomSDK/windows ...
```

### Option 3: Default Path Fallback

If no path is configured, the plugin will fall back to this location:

```bash
<PluginDirectory>/windows/libs/
```

You can either:

- Create a symbolic link, or  
- Copy the Zoom SDK to that path manually

> **Note**: Plugin packages are typically installed at:
>
> ```bash
> %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_zoom_meeting_sdk-0.0.7
> ```
>
> Replace `0.0.7` with your plugin version.

Refer to the [Dart environment documentation](https://dart.dev/tools/pub/environment-variables) for more on package locations.

## 4. Run the App

After setup, run your Flutter app, you should be able to launch without errors.:

```bash
flutter run
```

---

# Next Steps

- [Android Setup Instructions](./README_ANDROID.md)
- [iOS Setup Instructions](./README_IOS.md)
- [macOS Setup Instructions](./README_MACOS.md)
- [Back to Main README](./README.md)
