package com.revolution.revolution

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is REQUIRED by local_auth: the
// biometric prompt is a FragmentActivity-hosted dialog. Without this the App
// Lock's fingerprint/face/PIN prompt throws "no_fragment_activity" at runtime.
class MainActivity : FlutterFragmentActivity()
