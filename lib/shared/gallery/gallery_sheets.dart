import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_status.dart';
import 'component_gallery.dart';

/// Sheets and dialogs: `SheetHero` inline, and buttons that open each kind,
/// showing what the last one returned.
class SheetsGallerySection extends StatefulWidget {
  const SheetsGallerySection({super.key});

  @override
  State<SheetsGallerySection> createState() => _SheetsGallerySectionState();
}

class _SheetsGallerySectionState extends State<SheetsGallerySection> {
  String _last = 'nothing opened yet';

  void _show(String what, Object? result) {
    if (!mounted) return;
    setState(() => _last = '$what returned $result');
  }

  Future<void> _openOutOfBeans() async {
    final result = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => _OutOfBeansHero(
        onAnswer: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    _show('Out-of-beans sheet', result);
  }

  Future<void> _openLeave() async {
    final result = await showAppSheet<bool>(
      context: context,
      builder: (sheetContext) => SheetHero(
        illustration: const Icon(Icons.logout),
        illustrationSize: 96,
        tone: AppTone.tertiary,
        title: 'Leave this lesson?',
        body: "Your progress in this lesson won't be saved.",
        primaryAction: AppButton.primary(
          label: 'Keep learning',
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
        textAction: AppButton.text(
          label: 'Leave',
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
    );
    _show('Leave sheet', result);
  }

  Future<void> _openTall() async {
    final result = await showAppSheet<int>(
      context: context,
      builder: (sheetContext) => SheetHero(
        illustration: const Icon(Icons.flag),
        tone: AppTone.secondary,
        title: 'Pick a daily goal',
        body:
            'Taller than the screen on purpose: it scrolls, and the '
            'actions stay reachable.',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final minutes in const [5, 10, 15, 20, 30, 45, 60])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.spaceXs),
                child: AppCard(
                  onTap: () => Navigator.of(sheetContext).pop(minutes),
                  child: Text(
                    '$minutes minutes a day',
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
        textAction: AppButton.text(
          label: 'Not now',
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    _show('Tall sheet', result);
  }

  Future<void> _openLevelUp() async {
    final result = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => SheetHero(
        illustration: const Icon(Icons.workspace_premium),
        illustrationBadge: const RibbonBadge(
          label: 'LEVEL 5',
          tone: AppTone.secondary,
        ),
        tone: AppTone.secondary,
        title: 'Level up!',
        secondLanguage: 'እንኳን ደስ አለዎት!',
        phonetic: 'Enkwan des alowot!',
        body: 'Greetings is now level 5. Keep your streak going tomorrow.',
        primaryAction: AppButton.primary(
          label: 'Continue',
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    );
    _show('Level-up dialog', result);
  }

  Future<void> _openConfirm() async {
    final result = await showAppConfirmDialog(
      context: context,
      title: 'Delete this download?',
      message: 'You can download it again any time you are online.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    _show('Confirm dialog', result);
  }

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'Sheets and dialogs',
      note:
          'showAppSheet (cream, 32 px top, handle), showAppDialog (white '
          'card on a deep shelf) and showAppConfirmDialog, all laid out with '
          'SheetHero over the warm backdrop.',
      children: [
        GalleryCase(
          label: 'SheetHero, as the out-of-beans sheet lays it out',
          child: AppCard(child: _OutOfBeansHero(onAnswer: (_) {})),
        ),
        GalleryCase(
          label: 'open one: $_last',
          child: Wrap(
            spacing: AppSpacing.spaceSm,
            runSpacing: AppSpacing.spaceSm,
            children: [
              AppButton.secondary(
                label: 'Out of beans',
                onPressed: _openOutOfBeans,
                expand: false,
                size: AppButtonSize.compact,
              ),
              AppButton.secondary(
                label: 'Leave sheet',
                onPressed: _openLeave,
                expand: false,
                size: AppButtonSize.compact,
              ),
              AppButton.secondary(
                label: 'Tall sheet',
                onPressed: _openTall,
                expand: false,
                size: AppButtonSize.compact,
              ),
              AppButton.secondary(
                label: 'Level-up dialog',
                onPressed: _openLevelUp,
                expand: false,
                size: AppButtonSize.compact,
              ),
              AppButton.secondary(
                label: 'Delete confirm',
                onPressed: _openConfirm,
                expand: false,
                size: AppButtonSize.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The out-of-beans mockup, rebuilt from the library.
class _OutOfBeansHero extends StatelessWidget {
  const _OutOfBeansHero({required this.onAnswer});

  final ValueChanged<String?> onAnswer;

  @override
  Widget build(BuildContext context) {
    return SheetHero(
      illustration: const Icon(Icons.local_cafe),
      illustrationBadge: const CountBadge(
        label: '0 / 5',
        icon: Icons.local_cafe,
        tone: AppTone.tertiary,
      ),
      tone: AppTone.tertiary,
      title: 'Out of beans!',
      secondLanguage: 'ቡና አለቀ!',
      phonetic: 'Buna aleke!',
      body:
          "Don't worry, mistakes help you brew fluency! Beans refill "
          'automatically over time.',
      content: AppCard(
        topStripe: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.hourglass_top,
                  tone: AppTone.tertiary,
                  square: true,
                ),
                const SizedBox(width: AppSpacing.spaceXs),
                Expanded(
                  child: Text(
                    'Next bean in 12:34',
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            const AppProgressBar(
              value: 0.65,
              tone: AppTone.secondary,
              gradient: true,
              startLabel: 'Refills 1 bean every 30 minutes',
              endLabel: '65%',
              semanticLabel: 'Next bean',
            ),
          ],
        ),
      ),
      primaryAction: AppButton.accent(
        label: 'Refill with Amole',
        leading: const Icon(Icons.bolt),
        badge: const AppButtonBadge(label: '350', icon: Icons.diamond),
        onPressed: () => onAnswer('refill'),
      ),
      secondaryAction: AppButton.secondary(
        label: 'Practice for free beans',
        leading: const Icon(Icons.school),
        onPressed: () => onAnswer('practice'),
      ),
      textAction: AppButton.text(
        label: 'Not now',
        onPressed: () => onAnswer(null),
      ),
    );
  }
}
