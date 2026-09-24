import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('colours', () {
    test(
      'should match DESIGN.md and the mockups for every token added by 018',
      () {
        const expected = {
          'answerSelected': (AppColors.answerSelected, 0xFFFFF7ED),
          'answerCorrect': (AppColors.answerCorrect, 0xFFE8F8F0),
          'answerIncorrect': (AppColors.answerIncorrect, 0xFFFDF0EE),
          'optionChosen': (AppColors.optionChosen, 0xFFF0F7F2),
          'tileBorder': (AppColors.tileBorder, 0xFFE5DDD0),
          'tileShelf': (AppColors.tileShelf, 0xFFD5CCBD),
          'lockedNode': (AppColors.lockedNode, 0xFFE8DFD3),
          'lockedNodeIcon': (AppColors.lockedNodeIcon, 0xFFBAAFA1),
          'activeNodeShelf': (AppColors.activeNodeShelf, 0xFFC47318),
          'streak': (AppColors.streak, 0xFFFF5A1F),
          'streakRim': (AppColors.streakRim, 0xFFFFA726),
          'gem': (AppColors.gem, 0xFF10B981),
          'xp': (AppColors.xp, 0xFF0EA5E9),
          'textMuted': (AppColors.textMuted, 0xFF786A5E),
          'track': (AppColors.track, 0xFFE2D9CC),
          'shadowInk': (AppColors.shadowInk, 0xFF231A11),
        };
        for (final MapEntry(key: name, value: (colour, argb))
            in expected.entries) {
          expect(colour.toARGB32(), argb, reason: name);
        }
      },
    );

    test(
      'should make the scrim the warm vignette at 45% (DESIGN.md overlays)',
      () {
        expect(AppColors.scrim.toARGB32() & 0x00FFFFFF, 0x2B2118);
        expect(AppColors.scrim.a, closeTo(0.45, 0.01));
      },
    );
  });

  group('radii', () {
    test('should give tiles 20 and cards 24 (DESIGN.md "Shapes")', () {
      expect(AppRadii.tile, 20);
      expect(AppRadii.card, 24);
    });
  });

  group('shadows', () {
    test('should draw a shelf as a solid, unblurred offset of its colour', () {
      final shelf = AppShadows.shelf(AppColors.primaryBevel, depth: 5);
      expect(shelf.color, AppColors.primaryBevel);
      expect(shelf.offset, const Offset(0, 5));
      expect(shelf.blurRadius, 0);
    });

    test('should rest a card on its 4px bevel shelf plus a soft shadow', () {
      final [shelf, soft] = AppShadows.card;
      expect(shelf.color, AppColors.cardBevelDefault);
      expect(shelf.offset, const Offset(0, AppShadows.shelfDepth));
      expect(shelf.blurRadius, 0);
      expect(soft.blurRadius, greaterThan(0));
      expect(soft.color.a, closeTo(0.08, 0.01));
    });

    test(
      'should rest a tile on the 3px tile shelf (DESIGN.md component 4)',
      () {
        final shelf = AppShadows.tile.first;
        expect(shelf.color, AppColors.tileShelf);
        expect(shelf.offset, const Offset(0, 3));
        expect(shelf.blurRadius, 0);
      },
    );

    test('should flatten a button shadow as the button is pressed', () {
      final rest = AppShadows.button(AppColors.primaryBevel);
      expect(rest.first.offset, const Offset(0, 4));
      expect(rest.first.color, AppColors.primaryBevel);

      final half = AppShadows.button(AppColors.primaryBevel, visible: 0.5);
      expect(half.first.offset, const Offset(0, 2));

      expect(AppShadows.button(AppColors.primaryBevel, visible: 0), isEmpty);
      expect(AppShadows.button(AppColors.primaryBevel, visible: -0.1), isEmpty);
    });

    test('should let the shelf overshoot while the soft glow stays capped', () {
      final spring = AppShadows.button(AppColors.primaryBevel, visible: 1.2);
      expect(spring.first.offset.dy, closeTo(4.8, 0.001));
      final restGlow = AppShadows.button(AppColors.primaryBevel)[1].color.a;
      expect(spring[1].color.a, closeTo(restGlow, 0.001));
    });

    test('should give overlays and glows the DESIGN.md blurs', () {
      final overlay = AppShadows.overlay.single;
      expect(overlay.offset, const Offset(0, 16));
      expect(overlay.blurRadius, 32);
      expect(overlay.spreadRadius, -8);
      final glow = AppShadows.glow(AppColors.secondaryBrand).single;
      expect(glow.blurRadius, 20);
      expect(glow.color.a, closeTo(0.35, 0.01));
    });
  });

  group('motion', () {
    test('should press in faster than it springs back', () {
      expect(AppMotion.pressIn, lessThan(AppMotion.pressOut));
      expect(AppMotion.pressIn.inMilliseconds, 60);
      expect(AppMotion.pressOut.inMilliseconds, 180);
      expect(AppMotion.state.inMilliseconds, 150);
      expect(AppMotion.shake.inMilliseconds, 400);
    });

    testWidgets('should report reduced motion from the system setting', (
      tester,
    ) async {
      late bool reduced;
      Widget probe(bool disable) => MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: Builder(
          builder: (context) {
            reduced = AppMotion.reduced(context);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(probe(true));
      expect(reduced, isTrue);
      await tester.pumpWidget(probe(false));
      expect(reduced, isFalse);
    });
  });

  group('typography', () {
    const styles = {
      'displayLg': AppTypography.displayLg,
      'displayLgMobile': AppTypography.displayLgMobile,
      'headlineLg': AppTypography.headlineLg,
      'headlineMd': AppTypography.headlineMd,
      'headlineSm': AppTypography.headlineSm,
      'bodyLg': AppTypography.bodyLg,
      'bodyMd': AppTypography.bodyMd,
      'bodySm': AppTypography.bodySm,
      'labelLg': AppTypography.labelLg,
      'labelMd': AppTypography.labelMd,
      'labelSm': AppTypography.labelSm,
      'phonetic': AppTypography.phonetic,
    };

    test(
      'should set every style in the bundled family with the Ethiopic fallback',
      () {
        for (final MapEntry(key: name, value: style) in styles.entries) {
          expect(style.fontFamily, 'PlusJakartaSans', reason: name);
          expect(style.fontFamilyFallback, ['NotoSansEthiopic'], reason: name);
        }
      },
    );

    test('should style pronunciation as muted body-sm at 500 (DESIGN.md)', () {
      expect(AppTypography.phonetic.fontSize, AppTypography.bodySm.fontSize);
      expect(AppTypography.phonetic.fontWeight, FontWeight.w500);
      expect(AppTypography.phonetic.color, AppColors.textMuted);
    });

    test('should detect Ethiopic in every Ethiopic block and nowhere else', () {
      expect(AppTypography.hasEthiopic('ቡና'), isTrue); // U+1200 block
      expect(AppTypography.hasEthiopic('ሀ'), isTrue); // U+1200, first
      expect(AppTypography.hasEthiopic('᎐'), isTrue); // U+1390, Supplement
      expect(AppTypography.hasEthiopic('ⶀ'), isTrue); // U+2D80, Extended
      expect(AppTypography.hasEthiopic('ꬁ'), isTrue); // U+AB01, Extended-A
      expect(AppTypography.hasEthiopic('Coffee, Buna maaloo'), isFalse);
      expect(AppTypography.hasEthiopic('café ñ ü'), isFalse);
      expect(AppTypography.hasEthiopic(''), isFalse);
    });

    test('should add the Ge\'ez line height to Fidel text only', () {
      const style = AppTypography.bodyMd;
      final fidel = AppTypography.forText(style, 'ሰላም Selam');
      expect(fidel.height, closeTo(style.height! * 1.18, 0.0001));
      expect(fidel.fontSize, style.fontSize);
      expect(AppTypography.forText(style, 'Selam'), same(style));
    });

    test('should build the app theme on the bundled family', () {
      final theme = AppTheme.light;
      expect(theme.textTheme.bodyMedium!.fontFamily, 'PlusJakartaSans');
      expect(
        theme.textTheme.bodyMedium!.fontFamilyFallback,
        contains('NotoSansEthiopic'),
      );
    });
  });
}
