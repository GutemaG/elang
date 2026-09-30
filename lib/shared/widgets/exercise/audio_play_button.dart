import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme_context.dart';
import '../../theme/app_motion.dart';
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
/// [playing] swaps the speaker for sound bars and adds a soft halo. While
/// it lasts the bars rise and fall and a ring swells out from the face
/// (bolt 058); with reduced motion the look stays still. The caller decides
/// how long it lasts -- the lesson keeps it for the whole clip.
/// [onPressed] is the caller's, so the lesson keeps calling its audio
/// player exactly as before.
class AudioPlayButton extends StatefulWidget {
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

  /// One cycle of the bars and the ring.
  static const Duration cycle = Duration(milliseconds: 1200);

  @override
  State<AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<AudioPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: AudioPlayButton.cycle,
  );

  double get _face => widget.size == AudioPlayButtonSize.large
      ? AudioPlayButton.largeFace
      : AudioPlayButton.smallFace;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(AudioPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  /// Runs only while playing, and never with reduced motion: nothing ticks
  /// at rest.
  void _syncMotion() {
    final animate = widget.playing && !AppMotion.reduced(context);
    if (animate && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!animate && _motion.isAnimating) {
      _motion
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = _face;
    final playing = widget.playing;
    final onPressed = widget.onPressed;
    final enabled = onPressed != null;
    final moving = _motion.isAnimating;
    final glyphSize = face * 0.45;

    final button = TactilePressable(
      onPressed: onPressed,
      faceColor: context.colors.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.full),
      shelfDepth: AppShadows.shelfDepth,
      height: face,
      shadows: (visible) => [
        if (playing) ...AppShadows.halo(context.colors.primaryToneBorder),
        ...AppShadows.button(context.colors.primaryShelf, visible: visible),
      ],
      child: SizedBox.square(
        dimension: face,
        child: Center(
          child: playing
              ? AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => CustomPaint(
                    key: const ValueKey('audio-play-button-bars'),
                    size: Size.square(glyphSize),
                    painter: SoundBarsPainter(
                      phase: moving ? _motion.value : null,
                      color: context.colors.onPrimary,
                    ),
                  ),
                )
              : Icon(
                  Icons.volume_up,
                  size: glyphSize,
                  color: context.colors.onPrimary,
                ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: playing ? 'Playing audio' : widget.semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        // The small face is under 48 px wide; its tap target is not.
        child: SizedBox(
          width: face < AppButton.minTapTarget ? AppButton.minTapTarget : face,
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              width: face,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (moving)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: face,
                      height: face,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _motion,
                          builder: (context, _) =>
                              _Ring(progress: _motion.value),
                        ),
                      ),
                    ),
                  button,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A ring the size of the face, swelling out and fading once per cycle.
class _Ring extends StatelessWidget {
  const _Ring({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOut.transform(progress);
    return Transform.scale(
      key: const ValueKey('audio-play-button-ring'),
      scale: 1 + 0.45 * eased,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: context.colors.primaryContainer.withValues(
              alpha: 0.55 * (1 - eased),
            ),
            width: 3,
          ),
        ),
      ),
    );
  }
}

/// Four rounded sound bars (bolt 058). With a [phase] (0-1, one cycle)
/// they rise and fall out of step, each back where it started at the end
/// of the cycle so the loop never jumps; without one they rest at fixed
/// heights, the still look reduced motion keeps.
@visibleForTesting
class SoundBarsPainter extends CustomPainter {
  const SoundBarsPainter({required this.phase, required this.color});

  final double? phase;
  final Color color;

  /// Rest heights, as a share of the glyph.
  static const _rest = [0.45, 0.85, 0.65, 0.35];

  /// How many times each bar rises in a cycle, and where it starts; whole
  /// numbers of rises keep the loop seamless.
  static const _speed = [1, 2, 1, 2];
  static const _offset = [0.0, 0.3, 0.55, 0.8];

  /// Each bar's height now, as a share of the glyph.
  List<double> heights() {
    final at = phase;
    if (at == null) return _rest;
    return [
      for (var i = 0; i < _rest.length; i++)
        0.3 +
            0.7 *
                (0.5 +
                    0.5 *
                        math.sin(2 * math.pi * (_speed[i] * at + _offset[i]))),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bars = heights();
    // Bars and gaps share the width: four bars, three gaps of 60 % a bar.
    final barWidth = size.width / (bars.length + (bars.length - 1) * 0.6);
    final gap = barWidth * 0.6;
    for (var i = 0; i < bars.length; i++) {
      final height = size.height * bars[i];
      final left = i * (barWidth + gap);
      final top = (size.height - height) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SoundBarsPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
