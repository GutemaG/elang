import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_icon_button.dart';

/// Sheets and dialogs (018-mobile-design-system, FR-5): one bottom sheet,
/// one dialog, and the [SheetHero] layout both use, so a pop-up never looks
/// like a stock system dialog.

/// Opens a bottom sheet: cream, a 32 px top radius, a drag handle, the warm
/// backdrop and the overlay shadow (the out-of-beans mockup). It sizes to
/// its content; content taller than the screen scrolls under the handle.
///
/// Dismissal and the result are exactly [showModalBottomSheet]'s: a tap on
/// the backdrop, a drag down or back returns `null` unless [isDismissible]
/// or [enableDrag] turns that off.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: AppColors.surface.withValues(alpha: 0),
    elevation: 0,
    barrierColor: AppColors.scrim,
    constraints: const BoxConstraints(maxWidth: AppSheetFrame.maxWidth),
    builder: (sheetContext) =>
        AppSheetFrame(showHandle: enableDrag, child: builder(sheetContext)),
  );
}

/// The surface [showAppSheet] draws around its content.
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({super.key, required this.child, this.showHandle = true});

  final Widget child;
  final bool showHandle;

  static const double maxWidth = 640;
  static const double handleWidth = 32;
  static const double handleHeight = 4;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The keyboard shrinks the scrolling area rather than hiding the end of
    // it; the safe-area inset is just more padding under the content.
    final keyboard = media.viewInsets.bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
        boxShadow: AppShadows.overlay,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle)
              const Padding(
                padding: EdgeInsets.only(
                  top: AppSpacing.spaceSm,
                  bottom: AppSpacing.spaceXs,
                ),
                child: Center(child: _Handle()),
              )
            else
              const SizedBox(height: AppSpacing.spaceLg),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.spaceLg,
                  AppSpacing.spaceXs,
                  AppSpacing.spaceLg,
                  AppSpacing.spaceLg + media.padding.bottom,
                ),
                child: child,
              ),
            ),
            SizedBox(height: keyboard),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppSheetFrame.handleWidth,
        height: AppSheetFrame.handleHeight,
        decoration: BoxDecoration(
          color: AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
      ),
    );
  }
}

/// Opens a centred dialog card: white, a 2 px border, a 32 px radius and a
/// deep shelf (the level-up mockup), over the same warm backdrop as a
/// sheet. Its content scrolls when taller than the screen.
///
/// Dismissal and the result are exactly [showDialog]'s. [showClose] adds a
/// round close button at the top right that returns `null`.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool showClose = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.scrim,
    builder: (dialogContext) => AppDialogFrame(
      onClose: showClose ? () => Navigator.of(dialogContext).pop() : null,
      child: builder(dialogContext),
    ),
  );
}

/// Asks a yes/no question with [SheetHero]. Returns `true` for [confirmLabel],
/// `false` for [cancelLabel], and `null` if dismissed.
///
/// [destructive] is for an action that deletes or ends something: the
/// confirm button turns terracotta.
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) {
  return showAppDialog<bool>(
    context: context,
    showClose: false,
    builder: (dialogContext) {
      void answer(bool value) => Navigator.of(dialogContext).pop(value);
      return SheetHero(
        illustration: Icon(
          icon ?? (destructive ? Icons.delete_outline : Icons.help_outline),
        ),
        illustrationSize: 88,
        tone: destructive ? AppTone.tertiary : AppTone.primary,
        title: title,
        body: message,
        primaryAction: destructive
            ? AppButton.destructive(
                label: confirmLabel,
                onPressed: () => answer(true),
              )
            : AppButton.primary(
                label: confirmLabel,
                onPressed: () => answer(true),
              ),
        textAction: AppButton.text(
          label: cancelLabel,
          onPressed: () => answer(false),
        ),
      );
    },
  );
}

/// The card [showAppDialog] draws around its content.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({super.key, required this.child, this.onClose});

  final Widget child;
  final VoidCallback? onClose;

  static const double maxWidth = 400;
  static const double borderWidth = 2;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              // Room for the 8 px shelf under the card.
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: radius,
                    border: Border.all(
                      color: AppColors.surfaceContainerHighest,
                      width: borderWidth,
                    ),
                    boxShadow: AppShadows.dialog,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppRadii.lg - borderWidth,
                    ),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.spaceLg),
                          child: child,
                        ),
                        if (onClose != null)
                          Positioned(
                            top: AppSpacing.space2xs,
                            right: AppSpacing.space2xs,
                            child: AppIconButton(
                              icon: Icons.close,
                              tooltip: 'Close',
                              onPressed: onClose,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The content layout of every sheet and dialog (the out-of-beans and
/// level-up mockups): an illustration circle with a glow and an optional
/// badge, a title coloured by [tone], an optional second-language line with
/// its phonetic, the body, optional extra [content], and the action stack.
///
/// [illustration] is any widget (an [Icon] today, mascot art later); an
/// icon takes the tone's colour and 40 % of the circle.
class SheetHero extends StatelessWidget {
  const SheetHero({
    super.key,
    required this.illustration,
    required this.title,
    this.illustrationBadge,
    this.illustrationSize = 120,
    this.tone = AppTone.primary,
    this.secondLanguage,
    this.phonetic,
    this.body,
    this.content,
    this.primaryAction,
    this.secondaryAction,
    this.textAction,
  });

  final Widget illustration;

  /// Pinned to the circle's lower right, e.g. a [CountBadge] "0 / 5".
  final Widget? illustrationBadge;
  final double illustrationSize;
  final AppTone tone;
  final String title;

  /// The same message in Amharic (or the course language), e.g. "ቡና አለቀ!".
  final String? secondLanguage;

  /// How [secondLanguage] sounds, shown after it in brackets.
  final String? phonetic;
  final String? body;

  /// Anything between the body and the actions, e.g. a refill-timer card.
  final Widget? content;

  /// Usually [AppButton]s: primary, then secondary, then a text link.
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? textAction;

  static const double _maxBodyWidth = 320;

  @override
  Widget build(BuildContext context) {
    final titleColor = tone == AppTone.neutral ? AppColors.onSurface : tone.ink;
    final actions = [?primaryAction, ?secondaryAction];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _Illustration(hero: this)),
        const SizedBox(height: AppSpacing.spaceSm),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.forText(
              AppTypography.headlineLg.copyWith(color: titleColor),
              title,
            ),
          ),
        ),
        if (secondLanguage != null) ...[
          const SizedBox(height: AppSpacing.space2xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: secondLanguage,
                  style: AppTypography.forText(
                    AppTypography.headlineSm.copyWith(
                      color: AppColors.secondary,
                    ),
                    secondLanguage!,
                  ),
                ),
                if (phonetic != null)
                  TextSpan(
                    text: ' ($phonetic)',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (body != null) ...[
          const SizedBox(height: AppSpacing.spaceXs),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxBodyWidth),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: AppTypography.forText(
                  AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  body!,
                ),
              ),
            ),
          ),
        ],
        if (content != null) ...[
          const SizedBox(height: AppSpacing.spaceMd),
          content!,
        ],
        if (actions.isNotEmpty || textAction != null)
          const SizedBox(height: AppSpacing.spaceLg),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.spaceXs),
          actions[i],
        ],
        if (textAction != null) ...[
          if (actions.isNotEmpty) const SizedBox(height: AppSpacing.space2xs),
          Center(child: textAction),
        ],
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.hero});

  final SheetHero hero;

  @override
  Widget build(BuildContext context) {
    final size = hero.illustrationSize;
    // The circle is decoration; a badge ("0 / 5") carries meaning and is
    // read.
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ExcludeSemantics(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: AppShadows.halo(hero.tone.border),
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: hero.tone.icon, size: size * 0.4),
                child: hero.illustration,
              ),
            ),
          ),
          if (hero.illustrationBadge != null)
            Positioned(right: 0, bottom: 0, child: hero.illustrationBadge!),
        ],
      ),
    );
  }
}
