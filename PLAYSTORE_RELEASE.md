Google Play release checklist for this project

1. Confirm package id
- Current Android `applicationId`: `com.example.ai_quan_ly_chi_tieu_ca_nhan`
- Current Firebase Android package in `android/app/google-services.json`: `com.example.ai_quan_ly_chi_tieu_ca_nhan`
- If you want a real production package name, update both Android config and Firebase config first.

2. Create signing files
- Copy `android/key.properties.example` to `android/key.properties`
- Put your real keystore path and passwords into `android/key.properties`
- Keep `android/key.properties` out of git

3. Update app version
- Edit `version:` in `pubspec.yaml`
- Increase both the semantic version and build number

4. Build release bundle
- Command: `flutter build appbundle --release`
- Output: `build/app/outputs/bundle/release/app-release.aab`

5. Upload to Google Play Console
- Create app entry if it does not exist
- Complete store listing, content rating, privacy policy, testers, and app access fields
- Upload the generated `.aab`

Current blocker summary
- Release signing is now supported by `android/key.properties`
- Upload to Google Play still requires your Play Console access and real signing credentials
- If package id changes, Firebase Android config must be regenerated
