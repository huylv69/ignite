package tech.huylv.ignite

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth needs a FragmentActivity to host its biometric prompt; with a
// plain FlutterActivity every authenticate() call fails with
// "no_fragment_activity" at runtime.
class MainActivity : FlutterFragmentActivity()
