import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/app_page.dart';
import '../widgets/tactile_button.dart';
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
class ComponentGalleryApp extends StatelessWidget {
  const ComponentGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buna components',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const ComponentGallery(),
    );
  }
}

class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      topBar: AppTopBar(title: 'Buna components'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColoursSection(),
          _ShadowsSection(),
          _RadiiSection(),
          _MotionSection(),
          _TypeSection(),
          _ButtonsSection(),
          _IconButtonsSection(),
          _LegacyButtonSection(),
          PageShellGallerySection(),
          CardsGallerySection(),
          SheetsGallerySection(),
          StatusGallerySection(),
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
            style: AppTypography.headlineMd.copyWith(color: AppColors.primary),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              note!,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
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
            style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          child,
        ],
      ),
    );
  }
}

class _ColoursSection extends StatelessWidget {
  const _ColoursSection();

  static const _groups = <String, List<(String, Color)>>{
    'Surfaces': [
      ('background', AppColors.background),
      ('surfaceContainerLowest', AppColors.surfaceContainerLowest),
      ('surfaceContainerLow', AppColors.surfaceContainerLow),
      ('surfaceContainer', AppColors.surfaceContainer),
      ('surfaceContainerHigh', AppColors.surfaceContainerHigh),
      ('surfaceContainerHighest', AppColors.surfaceContainerHighest),
      ('surfaceDim', AppColors.surfaceDim),
    ],
    'Text and lines': [
      ('onSurface', AppColors.onSurface),
      ('onSurfaceVariant', AppColors.onSurfaceVariant),
      ('textMuted', AppColors.textMuted),
      ('outline', AppColors.outline),
      ('outlineVariant', AppColors.outlineVariant),
      ('track', AppColors.track),
    ],
    'Highland Acacia (primary)': [
      ('primary', AppColors.primary),
      ('primaryContainer', AppColors.primaryContainer),
      ('primaryBevel', AppColors.primaryBevel),
      ('primaryFixed', AppColors.primaryFixed),
    ],
    'Simien Gold (secondary)': [
      ('secondary', AppColors.secondary),
      ('secondaryContainer', AppColors.secondaryContainer),
      ('secondaryBrand', AppColors.secondaryBrand),
      ('secondaryBevel', AppColors.secondaryBevel),
      ('secondaryFixed', AppColors.secondaryFixed),
    ],
    'Rift Terracotta (tertiary)': [
      ('tertiary', AppColors.tertiary),
      ('tertiaryContainer', AppColors.tertiaryContainer),
      ('tertiaryBrand', AppColors.tertiaryBrand),
      ('tertiaryBevel', AppColors.tertiaryBevel),
      ('tertiaryFixed', AppColors.tertiaryFixed),
    ],
    'Cards and tiles': [
      ('cardBorderDefault', AppColors.cardBorderDefault),
      ('cardBevelDefault', AppColors.cardBevelDefault),
      ('tileBorder', AppColors.tileBorder),
      ('tileShelf', AppColors.tileShelf),
    ],
    'Answer states': [
      ('answerSelected', AppColors.answerSelected),
      ('answerCorrect', AppColors.answerCorrect),
      ('answerIncorrect', AppColors.answerIncorrect),
      ('optionChosen', AppColors.optionChosen),
    ],
    'Path nodes': [
      ('lockedNode', AppColors.lockedNode),
      ('lockedNodeIcon', AppColors.lockedNodeIcon),
      ('activeNodeShelf', AppColors.activeNodeShelf),
    ],
    'Gamification': [
      ('streak', AppColors.streak),
      ('streakRim', AppColors.streakRim),
      ('gem', AppColors.gem),
      ('xp', AppColors.xp),
    ],
    'Tones (AppTone)': [
      ('primaryToneBorder', AppColors.primaryToneBorder),
      ('primaryToneShelf', AppColors.primaryToneShelf),
      ('primaryToneSurface', AppColors.primaryToneSurface),
      ('secondaryToneBorder', AppColors.secondaryToneBorder),
      ('secondaryToneShelf', AppColors.secondaryToneShelf),
      ('tertiaryToneBorder', AppColors.tertiaryToneBorder),
      ('tertiaryToneShelf', AppColors.tertiaryToneShelf),
      ('tertiaryToneSurface', AppColors.tertiaryToneSurface),
    ],
    'Feedback and overlay': [
      ('error', AppColors.error),
      ('errorContainer', AppColors.errorContainer),
      ('scrim', AppColors.scrim),
      ('dialogShelf', AppColors.dialogShelf),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'Colours',
      note: 'Every colour a component may use (AppColors).',
      children: [
        for (final group in _groups.entries)
          GalleryCase(
            label: group.key,
            child: Wrap(
              spacing: AppSpacing.spaceSm,
              runSpacing: AppSpacing.spaceSm,
              children: [
                for (final (name, colour) in group.value)
                  _Swatch(name: name, colour: colour),
              ],
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.colour});

  final String name;
  final Color colour;

  String get _hex {
    final argb = colour.toARGB32().toRadixString(16).padLeft(8, '0');
    final rgb = '#${argb.substring(2).toUpperCase()}';
    return argb.startsWith('ff') ? rgb : '$rgb @${argb.substring(0, 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.outlineVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.space2xs),
          Text(
            name,
            style: AppTypography.labelSm.copyWith(color: AppColors.onSurface),
          ),
          Text(
            _hex,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
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
      ('card', AppShadows.card, AppColors.cardBorderDefault),
      ('tile', AppShadows.tile, AppColors.tileBorder),
      ('button(primaryBevel)', AppShadows.button(AppColors.primaryBevel), null),
      (
        'raised(primaryToneShelf)',
        AppShadows.raised(AppColors.primaryToneShelf),
        AppColors.primaryToneBorder,
      ),
      ('badge', AppShadows.badge, AppColors.outlineVariant),
      ('dialog', AppShadows.dialog, AppColors.surfaceContainerHighest),
      ('overlay', AppShadows.overlay, null),
      ('glow(secondaryBrand)', AppShadows.glow(AppColors.secondaryBrand), null),
      ('none (pressed)', AppShadows.none, AppColors.cardBorderDefault),
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
                        color: AppColors.surfaceContainerLowest,
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
                        color: AppColors.onSurface,
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
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: AppColors.tileBorder, width: 2),
                ),
                child: Text(
                  name,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurface,
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
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
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
                Text(_latin, style: style.copyWith(color: AppColors.onSurface)),
                Text(
                  _fidel,
                  style: AppTypography.forText(
                    style.copyWith(color: AppColors.onSurface),
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
                  AppTypography.headlineMd.copyWith(color: AppColors.tertiary),
                  'ቡና አለቀ!',
                ),
              ),
              const Text('Buna aleke!', style: AppTypography.phonetic),
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

class _LegacyButtonSection extends StatelessWidget {
  const _LegacyButtonSection();

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return const GallerySection(
      title: 'TactileButton (legacy)',
      note:
          'Still used by screens that have not moved to AppButton yet. It '
          'presses exactly like AppButton.',
      children: [
        GalleryCase(
          label: 'default',
          child: TactileButton(label: 'Continue', onPressed: _noop),
        ),
        GalleryCase(
          label: 'terracotta, as the lesson passes it after a wrong answer',
          child: TactileButton(
            label: 'Continue',
            onPressed: _noop,
            backgroundColor: AppColors.tertiaryBrand,
            bevelColor: AppColors.tertiaryBevel,
          ),
        ),
      ],
    );
  }
}
