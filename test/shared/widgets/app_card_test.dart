// AppCard and the pieces built on it, the tone table, and
// SelectableOptionCard on AppCard (018-mobile-design-system, story 006).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_card.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/selectable_option_card.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [child],
        ),
      ),
    ),
  ),
);

/// The decoration of the card's face, pressable or not.
BoxDecoration _face(WidgetTester tester, [Finder? of]) {
  final card = of ?? find.byType(AppCard);
  final pressable = find.descendant(
    of: card,
    matching: find.byType(TactilePressable),
  );
  if (pressable.evaluate().isNotEmpty) {
    final container = tester.widget<Container>(
      find.descendant(of: pressable, matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: card, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

double _luminance(Color c) => c.computeLuminance();

void main() {
  group('AppTone', () {
    test('should take borders and icon surfaces from the lesson-complete '
        'stat cards', () {
      expect(AppTone.primary.border, const Color(0xFFD1E8D9));
      expect(AppTone.primary.surface, const Color(0xFFE5F5EC));
      expect(AppTone.secondary.border, const Color(0xFFF3DFC7));
      expect(AppTone.tertiary.border, const Color(0xFFFBD6CF));
      expect(AppTone.tertiary.surface, const Color(0xFFFEE9E6));
      expect(AppTone.neutral.border, AppColors.cardBorderDefault);
      expect(AppTone.neutral.shelf, AppColors.cardBevelDefault);
    });

    test('should give every tone a shelf darker than its border', () {
      for (final tone in AppTone.values) {
        expect(
          _luminance(tone.shelf),
          lessThan(_luminance(tone.border)),
          reason: tone.name,
        );
      }
    });
  });

  group('a filled card (020-dashboard-section-header)', () {
    test("every tone's fill shelf is darker than its fill", () {
      for (final tone in AppTone.values) {
        expect(
          _luminance(tone.fillShelf),
          lessThan(_luminance(tone.fill)),
          reason: tone.name,
        );
      }
    });

    testWidgets('face and border take the fill, and the shelf the fill '
        'shelf', (tester) async {
      for (final tone in [
        AppTone.primary,
        AppTone.secondary,
        AppTone.tertiary,
      ]) {
        await tester.pumpWidget(
          _host(AppCard(tone: tone, filled: true, child: const Text('x'))),
        );
        final face = _face(tester);
        expect(face.color, tone.fill, reason: tone.name);
        expect((face.border! as Border).top.color, tone.fill);
        expect(face.boxShadow!.first.color, tone.fillShelf);
      }
    });

    testWidgets("a progress bar on a filled card fills with the tone's "
        'onFill over a faint wash of it, so a full bar still shows', (
      tester,
    ) async {
      for (final tone in [
        AppTone.primary,
        AppTone.secondary,
        AppTone.tertiary,
      ]) {
        await tester.pumpWidget(
          _host(AppProgressBar(value: 1, tone: tone, onFilled: true)),
        );
        await tester.pumpAndSettle();
        final boxes = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(AppProgressBar),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((b) => (b.decoration as BoxDecoration).color)
            .toList();
        expect(boxes, contains(tone.onFill), reason: tone.name);
        expect(boxes, isNot(contains(tone.fill)), reason: tone.name);
        final track = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AppProgressBar),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (track.decoration! as BoxDecoration).color,
          tone.onFill.withValues(alpha: 0.25),
        );
      }
    });

    testWidgets('a pressable filled card is filled too', (tester) async {
      await tester.pumpWidget(
        _host(
          AppCard(
            tone: AppTone.secondary,
            filled: true,
            onTap: () {},
            child: const Text('x'),
          ),
        ),
      );
      expect(_face(tester).color, AppTone.secondary.fill);
    });
  });

  group('PathSectionDivider', () {
    testWidgets('is the title, grey and in italics, between two hairlines', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const PathSectionDivider(title: 'Family & People')),
      );
      final text = tester.widget<Text>(find.text('Family & People'));
      expect(text.style!.color, AppColors.textMuted);
      expect(text.style!.fontStyle, FontStyle.italic);
      expect(text.textAlign, TextAlign.center);
      final lines = find.descendant(
        of: find.byType(PathSectionDivider),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.outlineVariant,
        ),
      );
      expect(lines, findsNWidgets(2));
      final title = tester.getRect(find.text('Family & People'));
      expect(tester.getRect(lines.first).right, lessThan(title.left));
      expect(tester.getRect(lines.last).left, greaterThan(title.right));
      // No card, no colour.
      expect(find.byType(AppCard), findsNothing);
    });

    testWidgets('a long title wraps to two lines, and each hairline keeps '
        'its minimum', (tester) async {
      await tester.pumpWidget(
        _host(
          const PathSectionDivider(
            title:
                'Colours, Body & Health and other very long section names '
                'that go on and on and on',
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
      final lines = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppColors.outlineVariant,
      );
      // Both hairlines are the same const widget, so each is measured
      // through its own element.
      expect(lines, findsNWidgets(2));
      for (final line in lines.evaluate()) {
        expect(
          (line.renderObject! as RenderBox).size.width,
          greaterThanOrEqualTo(PathSectionDivider.minLine - 0.5),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a screen reader hears it as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(const PathSectionDivider(title: 'Food')));
      expect(
        tester.getSemantics(find.text('Food')),
        isSemantics(label: 'Food', isHeader: true),
      );
      semantics.dispose();
    });
  });

  group('AppCard', () {
    testWidgets('should be a white face, 2 px border, 24 px radius and the '
        'card shadow', (tester) async {
      await tester.pumpWidget(_host(const AppCard(child: Text('Card'))));

      final face = _face(tester);
      expect(face.color, AppColors.surfaceContainerLowest);
      expect(face.borderRadius, BorderRadius.circular(AppRadii.card));
      final border = face.border! as Border;
      expect(border.top.width, 2);
      expect(border.top.color, AppColors.cardBorderDefault);
      expect(face.boxShadow, AppShadows.card);
    });

    testWidgets('should reserve the shelf below its face', (tester) async {
      await tester.pumpWidget(_host(const AppCard(child: Text('Card'))));

      final outer = tester.getRect(find.byType(AppCard));
      final face = tester.getRect(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(outer.bottom - face.bottom, AppShadows.shelfDepth);
    });

    for (final tone in [AppTone.primary, AppTone.secondary, AppTone.tertiary]) {
      testWidgets('${tone.name} should tint only the border and shelf', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(AppCard(tone: tone, child: const Text('Card'))),
        );

        final face = _face(tester);
        expect(face.color, AppColors.surfaceContainerLowest);
        expect((face.border! as Border).top.color, tone.border);
        expect(face.boxShadow, AppShadows.raised(tone.shelf));
      });
    }

    testWidgets('should draw the gradient band along the top only when '
        'asked', (tester) async {
      await tester.pumpWidget(
        _host(const AppCard(topStripe: true, child: Text('Card'))),
      );

      final stripe = find.byType(TibebStripe);
      expect(tester.widget<TibebStripe>(stripe).style, TibebStyle.gradient);
      // Inside the 2 px border, flush with its top.
      expect(
        tester.getRect(stripe).top - tester.getRect(find.byType(AppCard)).top,
        AppCard.borderWidth,
      );

      await tester.pumpWidget(_host(const AppCard(child: Text('Card'))));
      expect(find.byType(TibebStripe), findsNothing);
    });

    testWidgets('should pad its content 16, 12 or 0 px inside the border, '
        'tappable or not', (tester) async {
      for (final onTap in [null, () {}]) {
        for (final (padding, inset) in [
          (AppCardPadding.regular, AppSpacing.spaceMd),
          (AppCardPadding.compact, AppSpacing.spaceSm),
          (AppCardPadding.none, 0.0),
        ]) {
          await tester.pumpWidget(
            _host(
              AppCard(
                padding: padding,
                onTap: onTap,
                child: const Text('Card'),
              ),
            ),
          );
          final card = tester.getTopLeft(find.byType(AppCard));
          final text = tester.getTopLeft(find.text('Card'));
          final reason = '${padding.name}, tappable: ${onTap != null}';
          expect(
            text.dx - card.dx,
            AppCard.borderWidth + inset,
            reason: reason,
          );
          expect(
            text.dy - card.dy,
            AppCard.borderWidth + inset,
            reason: reason,
          );
        }
      }
    });

    testWidgets('should be a plain surface with no press or button role '
        'when not tappable', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(const AppCard(child: Text('Card'))));

      expect(find.byType(TactilePressable), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(find.text('Card')),
        isSemantics(label: 'Card', isButton: false),
      );
      semantics.dispose();
    });

    testWidgets('should press like a button and be one when tappable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(AppCard(onTap: () => taps++, child: const Text('Tap me'))),
      );

      expect(
        tester.getSemantics(find.byType(AppCard)),
        isSemantics(
          label: 'Tap me',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppCard)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      final sunk = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(TactilePressable),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .y;
      expect(sunk, AppShadows.shelfDepth);
      // Pressed, the shelf has gone and only the soft shadow remains.
      expect(_face(tester).boxShadow, [AppShadows.soft]);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('selected should take the tone\'s strong border and '
        'selected face, and say so', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AppCard(
            tone: AppTone.primary,
            selected: true,
            onTap: () {},
            child: const Text('Amharic'),
          ),
        ),
      );

      final face = _face(tester);
      expect(face.color, AppColors.optionChosen);
      expect((face.border! as Border).top.color, AppColors.primaryContainer);
      expect(
        tester.getSemantics(find.byType(AppCard)),
        isSemantics(
          label: 'Amharic',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('an unavailable choice should still be a button, disabled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const AppCard(selected: false, child: Text('Tigrinya'))),
      );

      expect(
        tester.getSemantics(find.byType(AppCard)),
        isSemantics(
          label: 'Tigrinya',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('should keep its white face inside a tinted parent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ColoredBox(
            color: AppColors.surfaceContainer,
            child: AppCard(tone: AppTone.secondary, child: Text('Card')),
          ),
        ),
      );

      expect(_face(tester).color, AppColors.surfaceContainerLowest);
    });
  });

  group('StatCard', () {
    Widget row({String? ribbon}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: StatCard(icon: Icons.star, value: '+25', label: 'XP EARNED'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.local_fire_department,
            value: '6 Days',
            label: 'STREAK',
            tone: AppTone.tertiary,
            ribbon: ribbon,
          ),
        ),
      ],
    );

    testWidgets('should show the icon circle, value and label', (tester) async {
      await tester.pumpWidget(_host(row()));

      expect(find.text('+25'), findsOneWidget);
      expect(find.text('XP EARNED'), findsOneWidget);
      expect(find.byType(IconBadge), findsNWidgets(2));
      final value = tester.widget<Text>(find.text('6 Days'));
      expect(value.style!.color, AppTone.tertiary.ink);
    });

    testWidgets('should fill its slot in a row', (tester) async {
      await tester.pumpWidget(_host(row()));

      final cards = find.byType(AppCard);
      expect(tester.getSize(cards.at(0)).width, (320 - 12) / 2);
      expect(tester.getSize(cards.at(1)).width, (320 - 12) / 2);
    });

    testWidgets('should hang its ribbon over the card\'s top edge', (
      tester,
    ) async {
      await tester.pumpWidget(_host(row(ribbon: '+1 TODAY')));

      final ribbon = tester.getRect(find.byType(RibbonBadge));
      final card = tester.getRect(find.byType(AppCard).at(1));
      expect(ribbon.center.dy, closeTo(card.top, 1));
      expect(ribbon.center.dx, closeTo(card.center.dx, 0.5));
      // It hangs over the card, not over whatever sits above the StatCard.
      expect(
        ribbon.top,
        greaterThanOrEqualTo(tester.getRect(find.byType(StatCard).at(1)).top),
      );
    });

    testWidgets('should line up with its neighbours whether or not it has '
        'a ribbon', (tester) async {
      await tester.pumpWidget(_host(row(ribbon: '+1 TODAY')));
      final withRibbon = tester.getRect(find.byType(AppCard).at(0)).top;
      expect(tester.getRect(find.byType(AppCard).at(1)).top, withRibbon);

      await tester.pumpWidget(_host(row()));
      expect(tester.getRect(find.byType(AppCard).at(1)).top, withRibbon);
    });

    testWidgets('should read as one phrase', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(row(ribbon: '+1 TODAY')));

      expect(
        tester.getSemantics(find.text('6 Days')),
        isSemantics(label: '6 Days\nSTREAK\n+1 TODAY'),
      );
      semantics.dispose();
    });
  });

  group('InfoBanner', () {
    testWidgets('should be a tinted stadium read as its message', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const InfoBanner(
            icon: Icons.local_cafe,
            message: 'Daily goal complete!',
          ),
        ),
      );

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InfoBanner),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, AppTone.secondary.surface);
      expect(decoration.borderRadius, BorderRadius.circular(AppRadii.full));
      expect((decoration.border! as Border).top.width, 1);
      expect(
        tester.getSemantics(find.byType(InfoBanner)),
        isSemantics(label: 'Daily goal complete!'),
      );
      semantics.dispose();
    });

    testWidgets('emphasis should strengthen the border', (tester) async {
      await tester.pumpWidget(
        _host(
          const InfoBanner(
            icon: Icons.sync_problem,
            tone: AppTone.tertiary,
            emphasis: true,
            message: 'Unsynced for 30+ days',
          ),
        ),
      );

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InfoBanner),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (box.decoration! as BoxDecoration).border! as Border;
      expect(border.top.width, 2);
      expect(border.top.color, AppTone.tertiary.icon);
    });
  });

  group('ListRow', () {
    testWidgets('should be at least 56 px with one line and 72 with two', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const ListRow(title: 'Sound')));
      expect(
        tester.getSize(find.byType(ListRow)).height,
        greaterThanOrEqualTo(ListRow.oneLineHeight),
      );

      await tester.pumpWidget(
        _host(const ListRow(title: 'Course', subtitle: 'Amharic')),
      );
      expect(
        tester.getSize(find.byType(ListRow)).height,
        greaterThanOrEqualTo(ListRow.twoLineHeight),
      );
    });

    testWidgets('should show a chevron and be one button when tappable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          ListRow(
            icon: Icons.person,
            title: 'Profile',
            subtitle: 'Name and email',
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ListRow)),
        isSemantics(
          label: 'Profile\nName and email',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(ListRow));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('should darken while pressed', (tester) async {
      await tester.pumpWidget(_host(ListRow(title: 'Profile', onTap: () {})));

      Color background() => tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(ListRow),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      expect(background().a, 0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListRow)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(background(), AppColors.surfaceContainerLow);

      await gesture.up();
      await tester.pump();
      expect(background().a, 0);
    });

    testWidgets('should keep a given trailing control and show no chevron '
        'when not tappable', (tester) async {
      await tester.pumpWidget(
        _host(const ListRow(title: 'Pack', trailing: Text('v3'))),
      );

      expect(find.text('v3'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('ListRowGroup', () {
    testWidgets('should put the rows on one card with a divider between '
        'each, starting where the text does', (tester) async {
      await tester.pumpWidget(
        _host(
          const ListRowGroup(
            children: [
              ListRow(icon: Icons.person, title: 'One'),
              ListRow(icon: Icons.flag, title: 'Two'),
              ListRow(icon: Icons.logout, title: 'Three'),
            ],
          ),
        ),
      );

      expect(find.byType(AppCard), findsOneWidget);
      final dividers = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppColors.cardBorderDefault,
      );
      expect(dividers, findsNWidgets(2));
      expect(
        tester.getTopLeft(dividers.first).dx,
        tester.getTopLeft(find.text('One')).dx,
      );
    });
  });

  group('SectionHeader', () {
    testWidgets('should be a heading with its eyebrow and action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const SectionHeader(
            eyebrow: 'Unit 2',
            title: 'Greetings',
            trailing: Text('See all'),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Greetings')),
        isSemantics(label: 'Unit 2\nGreetings', isHeader: true),
      );
      expect(find.text('See all'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('SelectableOptionCard on AppCard', () {
    Widget option({
      bool selected = false,
      bool enabled = true,
      VoidCallback? onTap,
    }) => SelectableOptionCard(
      leading: const Icon(Icons.translate),
      title: 'Amharic',
      subtitle: 'For English speakers',
      selected: selected,
      enabled: enabled,
      onTap: onTap,
    );

    testWidgets('unselected should be a neutral card with an empty radio', (
      tester,
    ) async {
      await tester.pumpWidget(_host(option(onTap: () {})));

      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.tone, AppTone.neutral);
      expect(card.selected, isFalse);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('selected should take the primary tone and show the check', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(option(selected: true, onTap: () {})));

      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.tone, AppTone.primary);
      expect(card.selected, isTrue);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AppCard)),
        isSemantics(isButton: true, hasSelectedState: true, isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('disabled should show the lock, ignore taps and say it is '
        'disabled', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(option(enabled: false, onTap: () => taps++)),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.byType(SelectableOptionCard));
      expect(taps, 0);
      expect(
        tester.getSemantics(find.byType(AppCard)),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      semantics.dispose();
    });

    testWidgets('should press like every other card', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(option(onTap: () => taps++)));

      expect(find.byType(TactilePressable), findsOneWidget);
      await tester.tap(find.byType(SelectableOptionCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
