# Google Play release guide

This repository is configured for a signed Google Play release.

## Release identity

- Application ID: `com.kiboard.kiboard_app`
- Version: `2.0.1` (`versionCode` 2)
- Target and compile SDK: Android 16 / API 36
- Artifact: `build/app/outputs/bundle/release/app-release.aab`
- License: MIT
- Privacy policy: <https://github.com/maxia-cl/KiBoard-app/blob/main/PRIVACY.md>

The application ID is permanent after the first Play Store publication. Every later release must
increase `versionCode` in `pubspec.yaml`.

## Signing

Use **Play App Signing** and let Google generate and protect the app-signing key. KiBoard keeps a
separate RSA 4096 upload key, used only to authenticate bundles sent to Play Console.

On a new Windows development machine, run once:

```powershell
.\tool\setup-android-signing.ps1
```

This writes the private key outside Git, under `%USERPROFILE%\.kiboard\signing`, and an ignored
`android/key.properties`. Back up both in a secure password manager. Never commit either file.

Build and verify locally:

```powershell
flutter analyze
flutter test
flutter build appbundle --release
```

The tag workflow needs these GitHub Actions secrets:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_STORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`

## Play Console

1. Create KiBoard in Play Console and keep the existing application ID.
2. Enrol in Play App Signing with a Google-generated app-signing key.
3. Upload `app-release.aab` to Internal testing first.
4. Use the public privacy-policy URL above.
5. Complete Data safety consistently with the policy. KiBoard has no accounts, ads, or KiBoard
   cloud backend. Declare app interactions collected for analytics: the Windows host sends fixed
   event identifiers and coarse context to Aptabase, never custom labels, actions, entered text,
   audio, pairing data, or app/window/device/deck names. Pairing data stays on device. Dictation
   invokes the Android speech recognition service and sends only the resulting text to the paired
   PC over the local network.
6. Declare microphone access for the user-initiated push-to-talk dictation feature.
7. Complete content rating, target audience, app access, ads, and the store listing.
8. Test the Play-generated build on both a phone and a tablet before promoting it to Production.

## Store copy

Short description:

> Turn your Android device into an automatic control deck for your Windows PC.

Full description:

> KiBoard turns your phone or tablet into a Wi-Fi control deck for Windows. It automatically
> follows the application you are using and shows the right controls, while the optional Manual
> mode lets you build your own decks. Launch or focus apps, run shortcuts and macros, control OBS,
> use a wireless trackpad, and dictate text. Pairing happens directly on your local network with an
> encrypted connection—no KiBoard account, ads, or KiBoard cloud service. Anonymous interaction
> analytics can be disabled from Settings. The open-source Windows companion is required and is
> available from the KiBoard GitHub repository.

Required visual assets still have to be uploaded through Play Console: app icon, feature graphic,
at least two phone screenshots, and tablet screenshots for tablet distribution.
