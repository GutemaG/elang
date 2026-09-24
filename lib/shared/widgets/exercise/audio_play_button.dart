import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../app_button.dart';
import '../tactile_pressable.dart';

/// How big an [AudioPlayButton] is.
enum AudioPlayButtonSize {
  /// 88 px: the listening question's main button.
  large,

  /// 44 px (48 px with its shelf): the speaker chip beside a question.
  small,
}

/// The one play button (018-mobile-design-system, FR-7): a round green
/// push button with a shelf, pressed like every tactile element.
///
/// [playing] swaps the speaker for sound waves and adds a soft halo. It is
/// a still look, not a looping animation; the caller decides how long it
/// lasts. [onPressed] is the caller's, so the lesson keeps calling its
/// audio player exactly as before.
class AudioPlayButton extends StatelessWidget {
  const AudioPlayButton({
    super.key,
    required this.onPressed,
    this.playing = false,
    this.size = AudioPlayButtonSize.large,
    this.semanticLabel = 'Play audio',
  });

  final VoidCallback? onPressed;
  final bool playing;
  final AudioPlayButtonSize size;

  /// What a screen reader hears at rest; while [playing] it hears
  /// "Playing audio".
  final String semanticLabel;

  static const double largeFace = 88;
  static const double smallFace = 44;

  double get _face => size == AudioPlayButtonSize.large ? largeFace : smallFace;

  @override
  Widget build(BuildContext context) {
    final face = _face;
    final enabled = onPressed != null;
    final button = TactilePressable(
      onPressed: onPressed,
      faceColor: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.full),
      shelfDepth: AppShadows.shelfDepth,
      height: face,
      shadows: (visible) => [
        if (playing) ...AppShadows.halo(AppColors.primaryToneBorder),
        ...AppShadows.button(AppColors.primaryBevel, visible: visible),
      ],
      child: SizedBox.square(
        dimension: face,
        child: Icon(
          playing ? Icons.graphic_eq : Icons.volume_up,
          size: face * 0.45,
          color: AppColors.onPrimary,
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: playing ? 'Playing audio' : semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        // The small face is under 48 px wide; its tap target is not.
        child: SizedBox(
          width: face < AppButton.minTapTarget ? AppButton.minTapTarget : face,
          child: Center(
            heightFactor: 1,
            child: SizedBox(width: face, child: button),
          ),
        ),
      ),
    );
  }
}
