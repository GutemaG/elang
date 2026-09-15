import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Renders Google's own GIS button. Required on Web: `authenticate()`
/// always throws there — Google requires the click to land directly on its
/// own rendered element (anti-phishing/FedCM policy), not one triggered
/// programmatically from a page-author-styled button. See
/// `GoogleWebSignInButton`'s doc comment for the full explanation.
Widget renderGoogleWebButton() {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      text: web.GSIButtonText.continueWith,
      shape: web.GSIButtonShape.pill,
    ),
  );
}
