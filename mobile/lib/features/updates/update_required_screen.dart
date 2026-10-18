import 'package:flutter/material.dart';

import '../../shared/l10n/app_language.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_theme_context.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_page.dart';

/// Shown in place of the app when this build is older than the backend
/// allows ([AppUpdateGate]): the learner can only update.
class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({super.key, required this.onUpdate});

  /// Opens the update: Play's update on Android, else the store page.
  final Future<void> Function() onUpdate;

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _opening = false;

  Future<void> _onUpdatePressed() async {
    setState(() => _opening = true);
    try {
      await widget.onUpdate();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppPage(
      background: AppPageBackground.celebration,
      bottomDock: [
        AppButton.primary(
          label: l.updateNow,
          onPressed: _opening ? null : _onUpdatePressed,
          leading: const Icon(Icons.system_update, size: 20),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.space2xl),
        child: Column(
          children: [
            Icon(
              Icons.system_update,
              size: 72,
              color: context.colors.primaryAccent,
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            Text(
              l.updateRequiredTitle,
              style: AppTypography.headlineMd.copyWith(
                color: context.colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              l.updateRequiredBody,
              style: AppTypography.bodyMd.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
