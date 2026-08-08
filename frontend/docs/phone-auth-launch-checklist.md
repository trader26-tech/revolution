# Phone Auth — Launch Checklist

Phone (OTP) login is **built and working** via Firebase. It's fully verified on
device with **test numbers** (Android emulator, real Android phone, real iPhone).

What's left before **real users get real SMS** is production registration — no
code rewrites, just account setup + config. This file lists exactly what remains.

---

## Current state (done)

- Firebase project `revolution-86562`, Phone provider enabled, SMS region allows India (+ Kuwait/USA if added).
- Android app `com.revolution.revolution` — real SMS **worked** on a real device (Galaxy M35); flaky only on debug builds (Play Integrity).
- iOS app `com.revolution.revolution.dev` (free-account dev bundle id) — builds, signs, installs, runs on real iPhone; verified via test number.
- Dart flow, OTP screen, "You're in." success animation, all edge cases hardened.
- Test numbers: `+91 89251 88870 → 123457`, `+91 99999 99999 → 123456`.

Test numbers **never send SMS** — they bypass Play Integrity (Android) and APNs
(iOS) entirely. They prove the app/flow, NOT real SMS delivery.

---

## iOS — make real SMS work  (needs paid Apple Developer account, ~$99/yr, ~1 hour)

1. **Create an APNs Auth Key** — Apple Developer → Certificates, IDs & Profiles →
   Keys → **+** → enable **Apple Push Notifications service (APNs)** → Continue →
   Register → **Download the `.p8`** (one-time download!). Note the **Key ID**.
2. **Get your Team ID** — Apple Developer → Membership.
3. **Upload to Firebase** — Console → Project Settings → **Cloud Messaging** tab →
   under the iOS app → **APNs Authentication Key** → upload `.p8` + Key ID + Team ID.
4. **Enable Push Notifications capability** in Xcode — Runner target → Signing &
   Capabilities → **+ Capability → Push Notifications**. (Adds an entitlements file.)
5. **Bundle id decision** — with a paid account you can register the real id
   `com.revolution.revolution`. Either keep `.dev` for dev builds + real id for
   release (recommended), or switch back and re-point Firebase (re-run
   `flutterfire configure` / update `firebase_options.dart` + `GoogleService-Info.plist`).

Result: real OTP SMS delivered to real iPhones (silent APNs verification;
reCAPTCHA fallback if a push can't be delivered). No app logic changes.

---

## Android — make real SMS fast & consistent  (needs Play Console, $25 one-time)

Real SMS already *works* on a real Android device — it's just slow/inconsistent
on **sideloaded debug builds** because Play Integrity doesn't recognize them.
Fix = get the app onto a Play Console track so Play recognizes it.

1. **Google Play Developer account** — $25 one-time. Identity verification can
   take 1–3 days (do this early).
2. **Generate a release build** — a signed App Bundle (`.aab`) with a release
   keystore (not the debug keystore).
3. **Upload to an internal testing track** — no public release needed.
4. **Add the release / Play app-signing SHA-256** to Firebase → Android app →
   fingerprints. (Play re-signs the app; use Play's app-signing SHA.)
5. Testers install via the internal-testing link → **real SMS works fast &
   consistently** (Play Integrity passes).

Result: real OTP SMS on all Android devices, no reCAPTCHA detour.

---

## The real end-to-end test (what actually proves it for users)

Test numbers with a memorized code do NOT prove real delivery. The real proof:
> A real person, on their own phone, enters their real number, receives an
> actual SMS they didn't know in advance, types it, and logs in.

Do this once per platform after the setup above — ideally with 2–3 different
people/numbers, including a non-India number if you allow those regions.

---

## Notes / gotchas already learned

- **Physical location doesn't affect SMS** — only the number's country + Firebase
  SMS region policy do. A Kuwait/USA number works from India if that region is allowed.
- **Rate limits** ("too many attempts") hit heavy testing on one number, not real
  users. Clears in a few hours; use a fresh or test number meanwhile.
- **iOS build uses Swift Package Manager**, not CocoaPods (system Ruby too old to
  install pods). Podfile is disabled (`Podfile.disabled`). Don't re-add the
  `Pods_Runner` framework refs — they cause `ld: framework 'Pods_Runner' not found`.
- **Don't `import FirebaseAuth` in AppDelegate** — breaks SPM linking; the plugin
  handles APNs automatically.
- **Deploy to iPhone** via `xcrun devicectl device install app` (fast, clear
  errors); `flutter run` wireless was unreliable. Debug builds can't launch from
  the home icon — use a **release** build for standalone use.
