import 'dart:async';

import 'package:flutter/widgets.dart';

import '../state/native_sign_in.dart';
import 'google_web_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_web_sign_in_button_web.dart'
    as impl;

/// Web-only replacement for the app's custom "Continue with Google" button.
///
/// On Web, `google_sign_in`'s `authenticate()` always throws
/// `UnimplementedError` — Google's identity flow (the GIS "Sign In With
/// Google" surface, as opposed to a generic OAuth token request) requires
/// the click to land directly on Google's own rendered button/iframe, not
/// one triggered programmatically from a page-author-styled element. This
/// is a deliberate anti-phishing/FedCM restriction, not a bug: it exists so
/// a malicious page can't draw a fake Google button that silently harvests
/// credentials.
///
/// This widget renders that real Google button (via `renderButton()`) and
/// listens to [GoogleNativeSignIn.webSignInTokens] for the ID token GIS
/// reports once the user completes sign-in inside it, forwarding it to
/// [onTokenAcquired] — the caller's job is only to call
/// `SignInController.completeWithExternallyAcquiredToken` with it, mirroring
/// what [GoogleNativeSignIn.signIn] would have returned on other platforms.
class GoogleWebSignInButton extends StatefulWidget {
  const GoogleWebSignInButton({
    super.key,
    required this.googleSignIn,
    required this.onTokenAcquired,
  });

  final GoogleNativeSignIn googleSignIn;
  final ValueChanged<String> onTokenAcquired;

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  StreamSubscription<String>? _subscription;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _subscription = widget.googleSignIn.webSignInTokens.listen(
      widget.onTokenAcquired,
    );
    // GIS's button requires initialize() to have completed before it can
    // render meaningfully.
    _ready = widget.googleSignIn.ensureInitialized();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 40);
        }
        return impl.renderGoogleWebButton();
      },
    );
  }
}
