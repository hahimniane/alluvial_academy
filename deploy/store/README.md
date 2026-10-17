# Store releases

`play.py` and `asc.py` talk to Google Play and App Store Connect directly.
No secrets live here: Play uses the service account at
`~/.play-publisher/key.json`; App Store Connect uses the API key at
`~/.appstoreconnect/private_keys/AuthKey_C7U4GRWF3Q.p8`.

Version convention: build number = version x 10000 (1.1.9 -> 11900).
Check both stores first (`play.py state`, `asc.py state`).

Android: copy the gitignored `android/key.properties` and
`android/upload-keystore.jks` into `android/`, then

    flutter build appbundle --release --build-name=X --build-number=N \
      --dart-define=STRIPE_PUBLISHABLE_KEY=<pk_live> --dart-define=FIREBASE_ENV=prod
    play.py release <aab> N X notes/X.json

iOS: Xcode has no signed-in Apple account on this machine, so `flutter build
ipa` cannot sign. Sign through the API key instead:

    flutter build ios --release --no-codesign <same flags>
    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
      -sdk iphoneos -archivePath <out>/Runner.xcarchive archive \
      -allowProvisioningUpdates -authenticationKeyPath <p8> \
      -authenticationKeyID C7U4GRWF3Q -authenticationKeyIssuerID 4ac4bd75-377b-4ec0-b769-a9ce5b64b216
    xcodebuild -exportArchive -archivePath <out>/Runner.xcarchive \
      -exportOptionsPlist deploy/store/ExportOptions.plist -exportPath <out>/ipa <same auth flags>
    xcrun altool --upload-app -f <ipa> -t ios --apiKey C7U4GRWF3Q --apiIssuer <issuer>
    asc.py submit N X notes/X.json   (after the build is VALID; set usesNonExemptEncryption false first)

The Zoom iOS SDK is referenced as `../../zoom-sdk-ios-6.6.9-github` from
`ios/`, i.e. a sibling of the repo folder; link `~/Downloads/zoom-sdk-ios-6.6.9-github` there.

Disk: an Android release build needs ~9 GB free (Gradle cache + intermediates).
Delete `build/app` and `~/.gradle/caches` after staging the AAB, before iOS.
