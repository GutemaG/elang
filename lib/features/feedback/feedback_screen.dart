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

class _CategoryOption {
  const _CategoryOption(this.category, this.icon, this.label, this.hint);

  final FeedbackCategory category;
  final IconData icon;
  final String label;
  final String hint;
}

const _categories = [
  _CategoryOption(
    FeedbackCategory.bug,
    Icons.bug_report,
    'Something broke',
    'What happened, and what were you doing just before?',
  ),
  _CategoryOption(
    FeedbackCategory.content,
    Icons.spellcheck,
    'A lesson mistake',
    'Which lesson, and what is wrong: a word, a translation, the audio?',
  ),
  _CategoryOption(
    FeedbackCategory.idea,
    Icons.lightbulb,
    'An idea',
    'What would make Buna better for you?',
  ),
  _CategoryOption(
    FeedbackCategory.other,
    Icons.chat_bubble,
    'Something else',
    'Tell us anything.',
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
            ? "That's plenty for today. Thank you! Try again tomorrow."
            : "Couldn't send. Check your connection and try again.",
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
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: 'Send feedback',
      ),
      bottomDock: [
        if (_sent)
          AppButton.primary(
            label: 'Done',
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
            label: 'Send',
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
    final hint = _categories
        .where((o) => o.category == _category)
        .map((o) => o.hint)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Tell us what's working and what isn't. We read every message.",
          style: AppTypography.bodyMd.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SectionHeader(title: 'What is it about?'),
        // Two rows of two, each row as tall as its taller tile, so long
        // labels and large text grow the tiles instead of overflowing.
        for (var row = 0; row < _categories.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.spaceSm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, option)
                    in _categories.skip(row).take(2).indexed) ...[
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
        const SectionHeader(title: 'How do you like Buna?'),
        RatingStars(
          rating: _rating,
          onChanged: (rating) => setState(() => _rating = rating),
        ),
        const SectionHeader(title: 'Your message'),
        AppTextArea(
          key: FeedbackScreen.messageKey,
          controller: _message,
          maxLength: FeedbackScreen.maxLength,
          hint: hint ?? 'Pick what it is about, then write here.',
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        Text(
          'Sent with your account and current course, so we can follow up.',
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
            'Thank you!',
            textAlign: TextAlign.center,
            style: AppTypography.headlineLg.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            'Your feedback is on its way to the Buna team.',
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
