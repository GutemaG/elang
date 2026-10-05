import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/l10n/app_language.dart';
import '../../shared/models/language_names.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_theme_context.dart';
import '../../shared/theme/app_tone.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_status.dart';
import '../../shared/widgets/glyph_tile.dart';
import '../lesson/widgets/pinned_header_sliver.dart';
import 'sound_chart.dart';
import 'sound_charts.dart';
import 'sound_player.dart';

/// The Sounds tab: every letter of the course's language with its sound
/// (the Fidel for Amharic, Qubee for Afaan Oromo). A tap plays the letter
/// and opens its sheet, with a slow play, its family and an example word.
///
/// Opens on the chart saved on the phone, so it shows at once and offline;
/// a newer one from the server replaces it when it arrives.
class SoundsScreen extends StatefulWidget {
  const SoundsScreen({
    super.key,
    required this.charts,
    required this.language,
    required this.player,
  });

  final SoundCharts charts;

  /// The language being learned, e.g. `am`.
  final String language;
  final SoundPlayer player;

  /// Each letter's tile, by letter id.
  static ValueKey<String> tileKey(String id) => ValueKey('sound-tile-$id');

  /// A letter of the family row in the open letter's sheet.
  static ValueKey<String> familyKey(String id) => ValueKey('sound-family-$id');

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

enum _Load { loading, ready, offline, none }

class _SoundsScreenState extends State<SoundsScreen> {
  SoundChart? _chart;
  _Load _state = _Load.loading;
  int _group = 0;

  @override
  void initState() {
    super.initState();
    widget.charts.addListener(_onCharts);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(SoundsScreen old) {
    super.didUpdateWidget(old);
    if (old.charts != widget.charts) {
      old.charts.removeListener(_onCharts);
      widget.charts.addListener(_onCharts);
    }
    if (old.language != widget.language) {
      _chart = null;
      _group = 0;
      _state = _Load.loading;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    widget.charts.removeListener(_onCharts);
    unawaited(widget.player.stop());
    super.dispose();
  }

  /// A newer version in the list: fetch it.
  void _onCharts() {
    final summary = widget.charts.summaryOf(widget.language);
    if (summary != null && summary.version != _chart?.version) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final language = widget.language;
    if (_chart == null) {
      final saved = await widget.charts.saved(language);
      if (!mounted || language != widget.language) return;
      if (saved != null) {
        setState(() {
          _chart = saved;
          _state = _Load.ready;
        });
      }
    }
    try {
      final fresh = await widget.charts.chart(language);
      if (!mounted || language != widget.language) return;
      setState(() {
        if (fresh == null) {
          _state = _Load.none;
          _chart = null;
        } else {
          _chart = fresh;
          _state = _Load.ready;
          _group = _group.clamp(0, fresh.groups.length - 1);
        }
      });
    } on Object {
      if (!mounted || language != widget.language) return;
      if (_chart == null) setState(() => _state = _Load.offline);
    }
  }

  void _retry() {
    setState(() => _state = _Load.loading);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      topBar: AppTopBar(title: context.l10n.tabSounds),
      scrollable: false,
      padded: false,
      body: switch (_state) {
        _Load.loading => const LoadingState(),
        _Load.offline => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: ErrorState(
              icon: Icons.wifi_off,
              title: context.l10n.soundsLoadFailed,
              message: context.l10n.soundsOffline,
              onRetry: _retry,
            ),
          ),
        ),
        _Load.none => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: EmptyState(
              icon: Icons.graphic_eq,
              title: context.l10n.tabSounds,
              message: context.l10n.soundsNone,
            ),
          ),
        ),
        _Load.ready => _chartView(context, _chart!),
      },
    );
  }

  Widget _chartView(BuildContext context, SoundChart chart) {
    final code = Localizations.localeOf(context).languageCode;
    final group = chart.groups[_group.clamp(0, chart.groups.length - 1)];
    final columns = group.columns;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            AppSpacing.space2xs,
            AppSpacing.marginMobile,
            AppSpacing.spaceSm,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.soundsSubtitle(
                    languageName(chart.language),
                    inLanguage(chart.title, code),
                  ),
                  style: AppTypography.forText(
                    AppTypography.labelLg.copyWith(
                      color: context.colors.onSurface,
                    ),
                    inLanguage(chart.title, code),
                  ),
                ),
                const SizedBox(height: AppSpacing.space2xs),
                Text(
                  context.l10n.soundsTapToHear,
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                if (chart.groups.length > 1) ...[
                  const SizedBox(height: AppSpacing.spaceSm),
                  Wrap(
                    spacing: AppSpacing.spaceXs,
                    runSpacing: AppSpacing.spaceXs,
                    children: [
                      for (var i = 0; i < chart.groups.length; i++)
                        _GroupChip(
                          label: inLanguage(chart.groups[i].names, code),
                          selected: i == _group,
                          onTap: () => setState(() => _group = i),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (columns != null && group.columnLabels.isNotEmpty)
          pinnedHeader(
            extent: 28,
            child: ColoredBox(
              color: context.colors.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      Expanded(
                        child: Text(
                          i < group.columnLabels.length
                              ? group.columnLabels[i]
                              : '',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSm.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            AppSpacing.space2xs,
            AppSpacing.marginMobile,
            AppSpacing.spaceLg,
          ),
          sliver: SliverGrid(
            gridDelegate: columns != null
                ? SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: _gap,
                    crossAxisSpacing: _gap,
                    mainAxisExtent: _tileHeight(context),
                  )
                : SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 84,
                    mainAxisSpacing: AppSpacing.spaceXs,
                    crossAxisSpacing: AppSpacing.spaceXs,
                    mainAxisExtent: _tileHeight(context) + 6,
                  ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final letter = group.letters[i];
              final kind = _kindName(context, letter);
              final label = context.l10n.soundsLetterLabel(
                letter.glyph,
                letter.romanization,
              );
              return GlyphTile(
                key: SoundsScreen.tileKey(letter.id),
                glyph: letter.glyph,
                caption: letter.romanization,
                muted: letter.sameAs != null,
                tone: letter.isVowel ? AppTone.primary : null,
                semanticLabel: kind == null ? label : '$label, $kind',
                onTap: () => _open(group, letter),
              );
            }, childCount: group.letters.length),
          ),
        ),
        if (group.letters.any((x) => x.isVowel))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              0,
              AppSpacing.marginMobile,
              AppSpacing.spaceMd,
            ),
            sliver: SliverToBoxAdapter(
              child: ExcludeSemantics(child: _KindKey(group: group)),
            ),
          ),
        if (chart.credits.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              0,
              AppSpacing.marginMobile,
              AppSpacing.spaceLg,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                context.l10n.soundsRecordedBy(chart.credits.join(', ')),
                style: AppTypography.bodySm.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static const double _gap = 6;

  /// Tall enough for a glyph and its romanization at the learner's text
  /// size.
  static double _tileHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return 52 * scale.clamp(1, 1.6) + AppShadows.tileShelfDepth;
  }

  Future<void> _play(String? url, {bool slow = false}) async {
    if (url == null) return;
    try {
      await widget.player.play(url, slow: slow);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.soundsCantPlay)));
    }
  }

  void _open(SoundGroup group, SoundLetter letter) {
    unawaited(_play(letter.audioUrl));
    unawaited(
      showAppSheet<void>(
        context: context,
        builder: (_) =>
            _LetterSheet(group: group, initial: letter, play: _play),
      ),
    );
  }
}

/// "Vowel" or "Consonant" in the app language, or null for a letter the
/// chart does not mark.
String? _kindName(BuildContext context, SoundLetter letter) => letter.isVowel
    ? context.l10n.soundsVowel
    : letter.isConsonant
    ? context.l10n.soundsConsonant
    : null;

/// Under a group with vowels: what the green tiles mean.
class _KindKey extends StatelessWidget {
  const _KindKey({required this.group});

  final SoundGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: AppSpacing.space2xs),
        Text(
          label,
          style: AppTypography.forText(
            AppTypography.bodySm.copyWith(color: colors.textMuted),
            label,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: AppSpacing.spaceMd,
      runSpacing: AppSpacing.space2xs,
      children: [
        item(
          const GlyphSwatch(tone: AppTone.primary),
          context.l10n.soundsVowel,
        ),
        if (group.letters.any((x) => x.isConsonant))
          item(const GlyphSwatch(), context.l10n.soundsConsonant),
      ],
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.inverseSurface : colors.surfaceContainerLowest,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.inverseSurface : colors.cardBorder,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceSm,
                vertical: AppSpacing.space2xs,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: AppTypography.forText(
                    AppTypography.labelMd.copyWith(
                      color: selected
                          ? colors.inverseOnSurface
                          : colors.onSurfaceVariant,
                    ),
                    label,
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

/// One letter, large: its sound at both speeds, a tip for a hard one, the
/// rest of its family (the Fidel's row), and an example word.
class _LetterSheet extends StatefulWidget {
  const _LetterSheet({
    required this.group,
    required this.initial,
    required this.play,
  });

  final SoundGroup group;
  final SoundLetter initial;
  final Future<void> Function(String? url, {bool slow}) play;

  @override
  State<_LetterSheet> createState() => _LetterSheetState();
}

class _LetterSheetState extends State<_LetterSheet> {
  late SoundLetter _letter = widget.initial;

  List<SoundLetter> get _family {
    final rows = widget.group.columns == null
        ? const <List<SoundLetter>>[]
        : widget.group.rows;
    for (final row in rows) {
      if (row.any((x) => x.id == _letter.id)) return row;
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final code = Localizations.localeOf(context).languageCode;
    final hint = inLanguage(_letter.hint, code);
    final kind = _kindName(context, _letter);
    final example = _letter.example;
    final family = _family;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        AppSpacing.spaceXs,
        AppSpacing.marginMobile,
        AppSpacing.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GlyphHero(glyph: _letter.glyph),
              const SizedBox(width: AppSpacing.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _letter.romanization,
                      style: AppTypography.headlineMd.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    if (kind != null)
                      Text(
                        kind,
                        style: AppTypography.forText(
                          AppTypography.labelMd.copyWith(
                            color: _letter.isVowel
                                ? context.tone(AppTone.primary).ink
                                : colors.textMuted,
                          ),
                          kind,
                        ),
                      ),
                    if (_letter.sameAs != null)
                      Text(
                        context.l10n.soundsSameAs(_letter.sameAs!),
                        style: AppTypography.forText(
                          AppTypography.bodySm.copyWith(
                            color: colors.textMuted,
                          ),
                          _letter.sameAs!,
                        ),
                      ),
                    if (hint.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.space2xs,
                        ),
                        child: Text(
                          hint,
                          style: AppTypography.forText(
                            AppTypography.bodySm.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            hint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  label: context.l10n.soundsPlay,
                  leading: const Icon(Icons.volume_up),
                  onPressed: _letter.audioUrl == null
                      ? null
                      : () => widget.play(_letter.audioUrl),
                ),
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              Expanded(
                child: AppButton.secondary(
                  label: context.l10n.soundsSlow,
                  leading: const Icon(Icons.slow_motion_video),
                  onPressed: _letter.audioUrl == null
                      ? null
                      : () => widget.play(_letter.audioUrl, slow: true),
                ),
              ),
            ],
          ),
          if (family.length > 1) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            Row(
              children: [
                for (var i = 0; i < family.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.space2xs),
                  Expanded(child: _familyCell(context, family[i])),
                ],
              ],
            ),
          ],
          if (example != null) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.soundsExample,
                          style: AppTypography.labelSm.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        Text(
                          example.word,
                          style: AppTypography.forText(
                            AppTypography.headlineSm.copyWith(
                              color: colors.onSurface,
                            ),
                            example.word,
                          ),
                        ),
                        if ((example.romanization ?? '').isNotEmpty)
                          Text(
                            example.romanization!,
                            style: AppTypography.phonetic.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        if (inLanguage(example.meaning, code).isNotEmpty)
                          Text(
                            inLanguage(example.meaning, code),
                            style: AppTypography.bodySm.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (example.audioUrl != null)
                    AppIconButton(
                      icon: Icons.volume_up,
                      tooltip: context.l10n.soundsPlay,
                      onPressed: () => widget.play(example.audioUrl),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _familyCell(BuildContext context, SoundLetter letter) => GlyphChoice(
    key: SoundsScreen.familyKey(letter.id),
    glyph: letter.glyph,
    semanticLabel: context.l10n.soundsLetterLabel(
      letter.glyph,
      letter.romanization,
    ),
    selected: letter.id == _letter.id,
    onTap: () {
      setState(() => _letter = letter);
      unawaited(widget.play(letter.audioUrl));
    },
  );
}
