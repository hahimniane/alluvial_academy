package org.alluvaleducationhub.academy

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Extends FlutterFragmentActivity rather than FlutterActivity because
 * flutter_stripe needs it: the Stripe payment sheet is a DialogFragment, so it
 * requires a FragmentActivity host. With a plain FlutterActivity the plugin
 * refuses to initialize and paying an invoice from the Android app fails with
 * "Your Main Activity class ... is not a subclass FlutterFragmentActivity".
 */
class MainActivity : FlutterFragmentActivity()
