import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_context.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/app_page.dart';
import 'gallery_colours.dart';
import 'gallery_exercise.dart';
import 'gallery_sheets.dart';
import 'gallery_status.dart';
import 'gallery_surfaces.dart';

/// The debug-only component gallery (018-mobile-design-system, FR-10): every
/// token and every shared component in every state on one page, organised
/// like a Widgetbook catalogue, so a design can be checked against its
/// reference in one place.
///
/// Run it with `flutter run -t lib/gallery_main.dart`. The app's own
/// `main.dart` never imports it, so it is not part of the app.
///
/// The sun/moon button in the top bar redraws every page in the other theme
/// (022-light-and-dark-themes, story 005).
class ComponentGalleryApp extends StatefulWidget {
  const ComponentGalleryApp({super.key});

  @override
  State<ComponentGalleryApp> createState() => _ComponentGalleryAppState();
}

class _ComponentGalleryAppState extends State<ComponentGalleryApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buna components',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: ComponentGallery(
        dark: _mode == ThemeMode.dark,
        onToggleTheme: () => setState(
          () => _mode = _mode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
      ),
    );
  }
}

class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key, this.dark = false, this.onToggleTheme});

  /// Whether the gallery is drawn in the dark theme, for the switch's icon.
  final bool dark;

  /// Flips the gallery between light and dark; no switch without it.
  final VoidCallback? onToggleTheme;

  /// The light/dark switch in the top bar.
  static const themeSwitchKey = ValueKey('gallery-theme-switch');

  @override
  Widget build(BuildContext context) {
    return AppPage(
      topBar: AppTopBar(
        title: 'Buna components',
        trailing: [
          if (onToggleTheme != null)
            AppIconButton(
              key: themeSwitchKey,
              icon: dark ? Icons.light_mode : Icons.dark_mode,
              tooltip: dark ? 'Light theme' : 'Dark theme',
              onPressed: onToggleTheme,
            ),
        ],
      ),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoursGallerySection(),
          _ShadowsSection(),
          _RadiiSection(),
          _MotionSection(),
          _TypeSection(),
          _ButtonsSection(),
          _IconButtonsSection(),
          PageShellGallerySection(),
          CardsGallerySection(),
          SheetsGallerySection(),
          StatusGallerySection(),
          ExerciseGallerySection(),
        ],
      ),
    );
  }
}

/// One gallery entry: a heading, an optional note, then the samples.
class GallerySection extends StatelessWidget {
  const GallerySection({
    super.key,
    required this.title,
    required this.children,
    this.note,
  });

  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.headlineMd.copyWith(
              color: context.colors.primary,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              note!,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.spaceMd),
          ...children,
        ],
      ),
    );
  }
}

/// A labelled sample: what the state is, then the component in it.
class GalleryCase extends StatelessWidget {
  const GalleryCase({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          child,
        ],
      ),
    );
  }
}

class _ShadowsSection extends StatelessWidget {
  const _ShadowsSection();

  @override
  Widget build(BuildContext context) {
    final samples = <(String, List<BoxShadow>, Color?)>[
      ('card', context.shadows.card, context.colors.cardBorder),
      ('tile', context.shadows.tile, context.colors.tileBorder),
      (
        'button(primaryShelf)',
        AppShadows.button(context.colors.primaryShelf),
        null,
      ),
      (
        'raised(primaryToneShelf)',
        context.shadows.raised(context.colors.primaryToneShelf),
        context.colors.primaryToneBorder,
      ),
      ('badge', context.shadows.badge, context.colors.outlineVariant),
      (
        'dialog',
        context.shadows.dialog,
        context.colors.surfaceContainerHighest,
      ),
      ('overlay', context.shadows.overlay, null),
      (
        'glow(secondaryBrand)',
        AppShadows.glow(context.colors.secondaryBrand),
        null,
      ),
      ('none (pressed)', AppShadows.none, context.colors.cardBorder),
    ];
    return GallerySection(
      title: 'Shadows',
      note:
          'A solid shelf plus a faint soft shadow (AppShadows). Pressed, the '
          'shelf collapses.',
      children: [
        Wrap(
          spacing: AppSpacing.spaceLg,
          runSpacing: AppSpacing.spaceXl,
          children: [
            for (final (name, shadows, border) in samples)
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: border == null
                            ? null
                            : Border.all(color: border, width: 2),
                        boxShadow: shadows,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceSm),
                    Text(
                      name,
                      style: AppTypography.labelSm.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RadiiSection extends StatelessWidget {
  const _RadiiSection();

  @override
  Widget build(BuildContext context) {
    const radii = <(String, double)>[
      ('sm 8', AppRadii.sm),
      ('base 16', AppRadii.base),
      ('tile 20', AppRadii.tile),
      ('card 24', AppRadii.card),
      ('lg 32', AppRadii.lg),
      ('full', AppRadii.full),
    ];
    return GallerySection(
      title: 'Radii',
      note:
          'Buttons and chips are pills, answer tiles 20, cards 24 (AppRadii).',
      children: [
        Wrap(
          spacing: AppSpacing.spaceSm,
          runSpacing: AppSpacing.spaceSm,
          children: [
            for (final (name, radius) in radii)
              Container(
                width: 96,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: context.colors.tileBorder,
                    width: 2,
                  ),
                ),
                child: Text(
                  name,
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MotionSection extends StatelessWidget {
  const _MotionSection();

  @override
  Widget build(BuildContext context) {
    final rows = <(String, Duration)>[
      ('pressIn (ease-out)', AppMotion.pressIn),
      ('pressOut (spring back)', AppMotion.pressOut),
      ('state', AppMotion.state),
      ('shake', AppMotion.shake),
      ('progress', AppMotion.progress),
    ];
    return GallerySection(
      title: 'Motion',
      note:
          'Press any button below to feel pressIn and pressOut. With the '
          "system's reduced-motion setting on, buttons only darken.",
      children: [
        for (final (name, duration) in rows)
          Text(
            '$name: ${duration.inMilliseconds} ms',
            style: AppTypography.bodySm.copyWith(
              color: context.colors.onSurface,
            ),
          ),
      ],
    );
  }
}

class _TypeSection extends StatelessWidget {
  const _TypeSection();

  static const _latin = 'Coffee & Hospitality';
  static const _fidel = 'ቡና እና እንግዳ ተቀባይነት';

  @override
  Widget build(BuildContext context) {
    const styles = <(String, TextStyle)>[
      ('displayLg', AppTypography.displayLg),
      ('displayLgMobile', AppTypography.displayLgMobile),
      ('headlineLg', AppTypography.headlineLg),
      ('headlineMd', AppTypography.headlineMd),
      ('headlineSm', AppTypography.headlineSm),
      ('bodyLg', AppTypography.bodyLg),
      ('bodyMd', AppTypography.bodyMd),
      ('bodySm', AppTypography.bodySm),
      ('labelLg', AppTypography.labelLg),
      ('labelMd', AppTypography.labelMd),
      ('labelSm', AppTypography.labelSm),
    ];
    return GallerySection(
      title: 'Type',
      note:
          'Plus Jakarta Sans, with Noto Sans Ethiopic for Fidel. Fidel lines '
          'get extra line height (AppTypography.forText).',
      children: [
        for (final (name, style) in styles)
          GalleryCase(
            label: name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _latin,
                  style: style.copyWith(color: context.colors.onSurface),
                ),
                Text(
                  _fidel,
                  style: AppTypography.forText(
                    style.copyWith(color: context.colors.onSurface),
                    _fidel,
                  ),
                ),
              ],
            ),
          ),
        GalleryCase(
          label: 'Fidel with its pronunciation (phonetic)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ቡና አለቀ!',
                style: AppTypography.forText(
                  AppTypography.headlineMd.copyWith(
                    color: context.colors.tertiary,
                  ),
                  'ቡና አለቀ!',
                ),
              ),
              Text(
                'Buna aleke!',
                style: AppTypography.phonetic.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'AppButton',
      note:
          'One look per kind of action. Primary is the main action, '
          'secondary a real alternative, accent a spend or reward, '
          'destructive ends or deletes something, text dismisses.',
      children: [
        const GalleryCase(
          label: 'primary',
          child: AppButton.primary(label: 'Continue', onPressed: _noop),
        ),
        const GalleryCase(
          label: 'primary with a trailing icon',
          child: AppButton.primary(
            label: 'Get started',
            onPressed: _noop,
            trailing: Icon(Icons.arrow_forward),
          ),
        ),
        const GalleryCase(
          label: 'primary, disabled',
          child: AppButton.primary(label: 'Check', onPressed: null),
        ),
        const GalleryCase(
          label: 'primary, loading',
          child: AppButton.primary(
            label: 'Continue',
            onPressed: _noop,
            loading: true,
          ),
        ),
        const GalleryCase(
          label: 'secondary with a leading icon',
          child: AppButton.secondary(
            label: 'Practice for free beans',
            onPressed: _noop,
            leading: Icon(Icons.school),
          ),
        ),
        const GalleryCase(
          label: 'secondary, disabled',
          child: AppButton.secondary(label: 'Review mistakes', onPressed: null),
        ),
        const GalleryCase(
          label: 'accent with a badge',
          child: AppButton.accent(
            label: 'Refill with Amole',
            onPressed: _noop,
            leading: Icon(Icons.bolt),
            badge: AppButtonBadge(label: '350 Amole', icon: Icons.diamond),
          ),
        ),
        const GalleryCase(
          label: 'destructive',
          child: AppButton.destructive(label: 'Leave lesson', onPressed: _noop),
        ),
        GalleryCase(
          label: 'hugging their labels, compact',
          child: Wrap(
            spacing: AppSpacing.spaceSm,
            runSpacing: AppSpacing.spaceSm,
            children: const [
              AppButton.primary(
                label: 'Start',
                onPressed: _noop,
                expand: false,
                size: AppButtonSize.compact,
              ),
              AppButton.secondary(
                label: 'Later',
                onPressed: _noop,
                expand: false,
                size: AppButtonSize.compact,
              ),
              AppButton.destructive(
                label: 'Delete',
                onPressed: _noop,
                expand: false,
                size: AppButtonSize.compact,
              ),
            ],
          ),
        ),
        const GalleryCase(
          label: 'text: Skip, Cancel, Not now',
          child: Center(
            child: AppButton.text(label: 'Not now', onPressed: _noop),
          ),
        ),
        const GalleryCase(
          label: 'a Fidel label',
          child: AppButton.primary(label: 'እንጀምር', onPressed: _noop),
        ),
      ],
    );
  }
}

class _IconButtonsSection extends StatelessWidget {
  const _IconButtonsSection();

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return const GallerySection(
      title: 'AppIconButton',
      note: 'Close, back and other icon actions. 48×48 tap target.',
      children: [
        Row(
          children: [
            AppIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: _noop,
            ),
            SizedBox(width: AppSpacing.spaceSm),
            AppIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: _noop,
              plain: true,
            ),
            SizedBox(width: AppSpacing.spaceSm),
            AppIconButton(
              icon: Icons.settings,
              tooltip: 'Settings (disabled)',
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }
}
