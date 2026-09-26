import 'package:flutter/material.dart';

import '../widgets/app_page.dart';
import '../widgets/app_status.dart';

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
    return const AppPage(
      scrollable: false,
      body: EmptyState(
        icon: Icons.home_outlined,
        title: 'Home',
        message: 'Out of scope for this bolt.',
      ),
    );
  }
}
