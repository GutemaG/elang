import 'package:flutter/material.dart';

import 'features/auth/auth_dependencies.dart';
import 'features/auth/auth_routes.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(BunaApp(authDependencies: AuthDependencies()));
}

/// App root: wires the auth/onboarding route table (see
/// `lib/features/auth/auth_routes.dart`) with a single [AuthDependencies]
/// bag shared by every screen in that flow.
class BunaApp extends StatelessWidget {
  const BunaApp({super.key, required this.authDependencies});

  final AuthDependencies authDependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buna',
      theme: AppTheme.light,
      initialRoute: AuthRoutes.splash,
      routes: AuthRoutes.build(authDependencies),
    );
  }
}
