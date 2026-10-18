import 'package:flutter/material.dart';

import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_theme_context.dart';
import '../../shared/theme/app_tone.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_input.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_status.dart';
import 'feedback_api.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/l10n/app_language.dart';

class _CategoryOption {
  const _CategoryOption(this.category, this.icon, this.label, this.hint);

  final FeedbackCategory category;
  final IconData icon;
  final String label;
  final String hint;
}

/// The four kinds, in the app language [l].
List<_CategoryOption> _categoriesIn(AppLocalizations l) => [
  _CategoryOption(
    FeedbackCategory.bug,
    Icons.bug_report,
    l.feedbackBug,
    l.feedbackBugHint,
  ),
  _CategoryOption(
    FeedbackCategory.content,
    Icons.spellcheck,
    l.feedbackContent,
    l.feedbackContentHint,
  ),
  _CategoryOption(
    FeedbackCategory.idea,
    Icons.lightbulb,
    l.feedbackIdea,
    l.feedbackIdeaHint,
  ),
  _CategoryOption(
    FeedbackCategory.other,
    Icons.chat_bubble,
    l.feedbackOther,
    l.feedbackOtherHint,
  ),
];

/// "Send feedback" (027-learner-feedback), opened from Settings: what it is
/// about, an optional 1-5 rating and a message. The admin site lists what
/// arrives. A failed send keeps everything typed so it can be sent again.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.api});

  final FeedbackApi api;

  static const maxLength = 2000;
  static const messageKey = ValueKey('feedback-message');
  static const sendKey = ValueKey('feedback-send');

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  FeedbackCategory? _category;
  int? _rating;
  bool _sending = false;
  bool _sent = false;

  /// Why the last send failed, shown above the Send button (a snack bar
  /// would cover it).
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _ready =>
      _category != null && _message.text.trim().isNotEmpty && !_sending;

  Future<void> _send() async {
    final category = _category;
    if (category == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.send(
        category: category,
        message: _message.text.trim(),
        rating: _rating,
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on FeedbackApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.tooMany
            ? context.l10n.feedbackTooMany
            : context.l10n.feedbackSendFailed,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      topBar: AppTopBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          tooltip: context.l10n.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: context.l10n.sendFeedback,
      ),
      bottomDock: [
        if (_sent)
          AppButton.primary(
            label: context.l10n.done,
            onPressed: () => Navigator.of(context).maybePop(),
          )
        else ...[
          if (_error case final error?)
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: context.colors.error),
            ),
          AppButton.primary(
            key: FeedbackScreen.sendKey,
            label: context.l10n.send,
            leading: const Icon(Icons.send),
            loading: _sending,
            onPressed: _ready ? _send : null,
          ),
        ],
      ],
      body: _sent ? const _Thanks() : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final l = context.l10n;
    final categories = _categoriesIn(l);
    final hint = categories
        .where((o) => o.category == _category)
        .map((o) => o.hint)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.feedbackIntro,
          style: AppTypography.bodyMd.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SectionHeader(title: l.feedbackAbout),
        // Two rows of two, each row as tall as its taller tile, so long
        // labels and large text grow the tiles instead of overflowing.
        for (var row = 0; row < categories.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.spaceSm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, option)
                    in categories.skip(row).take(2).indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.spaceSm),
                  Expanded(
                    child: _CategoryTile(
                      option: option,
                      selected: _category == option.category,
                      onTap: () => setState(() => _category = option.category),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        SectionHeader(title: l.feedbackRating),
        RatingStars(
          rating: _rating,
          onChanged: (rating) => setState(() => _rating = rating),
        ),
        SectionHeader(title: l.feedbackMessage),
        AppTextArea(
          key: FeedbackScreen.messageKey,
          controller: _message,
          maxLength: FeedbackScreen.maxLength,
          hint: hint ?? l.feedbackPickFirst,
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        Text(
          l.feedbackSentWith,
          style: AppTypography.bodySm.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _CategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        tone: selected ? AppTone.primary : AppTone.neutral,
        selected: selected,
        padding: AppCardPadding.compact,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              icon: option.icon,
              tone: selected ? AppTone.primary : AppTone.secondary,
              size: 36,
            ),
            const SizedBox(height: AppSpacing.spaceXs),
            Text(
              option.label,
              style: AppTypography.labelLg.copyWith(
                color: selected
                    ? context.tone(AppTone.primary).ink
                    : context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thanks extends StatelessWidget {
  const _Thanks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space2xl),
      child: Column(
        children: [
          const IconBadge(
            icon: Icons.favorite,
            tone: AppTone.primary,
            size: 96,
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          Text(
            context.l10n.thankYou,
            textAlign: TextAlign.center,
            style: AppTypography.headlineLg.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            context.l10n.feedbackOnItsWay,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLg.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
