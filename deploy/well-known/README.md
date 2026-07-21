# Deep-link verification files (Universal Links / App Links)

These two files make the OS open the **Starlink mobile app** (instead of a browser)
when a user taps the password-reset link in their email:

```
https://starlink.ardentnetworks.com.ph/reset-password?token=...
```

They must be **hosted on the web server** for `starlink.ardentnetworks.com.ph`.
The app config (iOS entitlements, Android manifest, Dart handler) is already done in
this repo — these server files are the missing half.

## Where to host

| Platform | Exact URL (must be HTTPS, no redirects) |
|----------|------------------------------------------|
| iOS      | `https://starlink.ardentnetworks.com.ph/.well-known/apple-app-site-association` |
| Android  | `https://starlink.ardentnetworks.com.ph/.well-known/assetlinks.json` |

Rules:
- `apple-app-site-association` has **no file extension** and must be served with
  `Content-Type: application/json`.
- Both must return HTTP 200 directly (no 301/302 redirects, no auth wall).
- Test after deploy:
  - `curl -i https://starlink.ardentnetworks.com.ph/.well-known/apple-app-site-association`
  - `curl -i https://starlink.ardentnetworks.com.ph/.well-known/assetlinks.json`

## Values you MUST confirm/fill before hosting

1. **App identity** — these files assume the org-standard ids (matching eforward):
   - iOS `appID`: `K9973Z86YT.com.ardentnetworks.starlink`  (TeamID.bundleId)
   - Android `package_name`: `com.ardentnetworks.starlink`

   The app currently still ships with placeholders (`com.example.*`). The app's bundle
   id / package MUST equal the values in these files. Either update the app to
   `com.ardentnetworks.starlink` (recommended — see repo changes) or change these files
   to whatever id the app is actually built with.

2. **Android SHA-256 fingerprint** — replace `REPLACE_WITH_RELEASE_SIGNING_SHA256` in
   `assetlinks.json` with the fingerprint of the key that signs the shipped APK/AAB:

   - Release keystore:
     ```
     keytool -list -v -keystore <release.keystore> -alias <alias>
     ```
   - If distributing via Google Play (Play App Signing):
     Play Console → your app → Setup → App integrity → App signing key certificate → SHA-256.
   - For local debug-build testing only, use the debug key's SHA-256
     (generated on first Android build at `~/.android/debug.keystore`, password `android`):
     ```
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
     ```
   You can list multiple fingerprints in the array (e.g. debug + Play signing).

## Note
- After the files are live, reinstall the app — the OS fetches the association file at
  install time and caches the verification result.
