import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Stand-in destination for "the user is signed in / has a valid session."
///
/// The real home screen (skill tree dashboard) is a different, future
/// intent — out of scope for the 002-auth-onboarding-ui bolt, whose
/// acceptance criteria only require verifying the *routing decision*, not
/// home screen content. This exists purely so splash/sign-in have
/// somewhere concrete to navigate to.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Home (out of scope for this bolt)',
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        ),
      ),
    );
  }
}
