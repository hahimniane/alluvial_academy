This folder is intentionally empty for normal builds.

The Android wrapper now uses Zoom's official Maven Central artifact
`us.zoom.meetingsdk:zoomsdk`, so a local `mobilertc.aar` is not required for the
Play release build.

Only place `mobilertc.aar` here if you deliberately revert the Gradle dependency
to a local flatDir AAR for debugging a specific Zoom SDK package.
