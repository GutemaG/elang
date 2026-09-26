import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/app_page.dart';
import '../widgets/app_status.dart';
import '../widgets/selectable_option_card.dart';
import 'component_gallery.dart';

void _noop() {}

/// `AppPage` in its three backgrounds, each in a framed phone so the top
/// bar, dock and stripe show in place.
class PageShellGallerySection extends StatelessWidget {
  const PageShellGallerySection({super.key});

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'AppPage',
      note:
          'Every screen sits on AppPage: background, safe area, 20 px '
          'margins, top bar, a docked action stack and the Tibeb stripe.',
      children: [
        GalleryCase(
          label: 'plain, with a titled top bar and a dock',
          child: GalleryPhoneFrame(
            child: AppPage(
              topBar: AppTopBar(
                leading: const AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onPressed: _noop,
                ),
                title: 'Settings',
              ),
              body: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: 'Learning'),
                  ListRowGroup(
                    children: [
                      ListRow(
                        icon: Icons.flag,
                        tone: AppTone.secondary,
                        title: 'Daily goal',
                        trailing: _ValueText('10 min'),
                        onTap: _noop,
                      ),
                      ListRow(
                        icon: Icons.translate,
                        tone: AppTone.primary,
                        title: 'Course',
                        subtitle: 'Amharic for English speakers',
                        onTap: _noop,
                      ),
                    ],
                  ),
                ],
              ),
              bottomDock: const [
                AppButton.primary(label: 'Save', onPressed: _noop),
                AppButton.text(label: 'Cancel', onPressed: _noop),
              ],
            ),
          ),
        ),
        GalleryCase(
          label: 'patterned, with stat pills in the top bar',
          child: GalleryPhoneFrame(
            child: AppPage(
              background: AppPageBackground.patterned,
              topBar: const AppTopBar(
                trailing: [
                  StatPill(kind: StatKind.streak, value: 5),
                  StatPill(kind: StatKind.beans, value: 5, max: 5),
                  StatPill(kind: StatKind.xp, value: 340),
                ],
              ),
              body: const _MilestoneCard(),
            ),
          ),
        ),
        GalleryCase(
          label: 'celebration, with the brand bar, a dock and the stripe',
          child: GalleryPhoneFrame(
            child: AppPage(
              background: AppPageBackground.celebration,
              topBar: const AppTopBar.brand(
                leading: AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onPressed: _noop,
                  plain: true,
                ),
                trailing: [AppButton.text(label: 'Skip', onPressed: _noop)],
              ),
              body: const _StatCardRow(),
              bottomDock: const [
                AppButton.primary(
                  label: 'Continue',
                  onPressed: _noop,
                  trailing: Icon(Icons.arrow_forward),
                ),
              ],
              footerStripe: true,
            ),
          ),
        ),
        const GalleryCase(
          label: 'Tibeb stripes: woven (footer) and gradient (card top)',
          child: Column(
            children: [
              TibebStripe(),
              SizedBox(height: AppSpacing.spaceSm),
              TibebStripe(style: TibebStyle.gradient),
            ],
          ),
        ),
      ],
    );
  }
}

/// A phone-shaped window onto a page, so a whole [AppPage] can sit inside
/// the gallery's own scrolling page.
class GalleryPhoneFrame extends StatelessWidget {
  const GalleryPhoneFrame({super.key, required this.child});

  final Widget child;

  static const double height = 480;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.outlineVariant, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card - 2),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: child,
        ),
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
    );
  }
}

/// The dashboard mockup's "Current Milestone" card.
class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      topStripe: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current milestone',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      'Unit 1: Foundations & Greetings',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'ሰላምታ እና ፊደል መግቢያ',
                      style: AppTypography.forText(
                        AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        'ሰላምታ',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.spaceXs),
              const CountBadge(label: '3/5 Completed', icon: Icons.flag),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          const AppProgressBar(
            value: 0.6,
            gradient: true,
            semanticLabel: 'Unit progress',
          ),
        ],
      ),
    );
  }
}

/// The lesson-complete mockup's three stat cards.
class _StatCardRow extends StatelessWidget {
  const _StatCardRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.star,
            value: '+25',
            label: 'XP EARNED',
            tone: AppTone.secondary,
          ),
        ),
        SizedBox(width: AppSpacing.gutterMobile),
        Expanded(
          child: StatCard(
            icon: Icons.local_fire_department,
            value: '6 Days',
            label: 'STREAK',
            tone: AppTone.tertiary,
            ribbon: '+1 TODAY',
          ),
        ),
        SizedBox(width: AppSpacing.gutterMobile),
        Expanded(
          child: StatCard(
            icon: Icons.diamond,
            value: '+12',
            label: 'GEMS',
            tone: AppTone.primary,
          ),
        ),
      ],
    );
  }
}

/// `AppCard` and everything built on it.
class CardsGallerySection extends StatefulWidget {
  const CardsGallerySection({super.key});

  @override
  State<CardsGallerySection> createState() => _CardsGallerySectionState();
}

class _CardsGallerySectionState extends State<CardsGallerySection> {
  int _taps = 0;
  bool _sound = true;
  int _chosen = 0;

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.bodySm.copyWith(color: AppColors.onSurface);
    return GallerySection(
      title: 'AppCard',
      note:
          'Tactile Level 1: white face, 2 px border, 24 px radius, shelf and '
          'soft shadow. A tone tints only the border and shelf.',
      children: [
        for (final tone in AppTone.values)
          GalleryCase(
            label: 'tone: ${tone.name}',
            child: AppCard(
              tone: tone,
              child: Text('A ${tone.name} card', style: body),
            ),
          ),
        GalleryCase(
          label: 'top stripe, compact',
          child: AppCard(
            topStripe: true,
            padding: AppCardPadding.compact,
            child: Text('The refill-timer card has this band', style: body),
          ),
        ),
        GalleryCase(
          label: 'tappable: presses like a button (tapped $_taps times)',
          child: AppCard(
            onTap: () => setState(() => _taps++),
            child: Text('Tap me', style: body),
          ),
        ),
        GalleryCase(
          label: 'selected, primary tone',
          child: AppCard(
            tone: AppTone.primary,
            selected: true,
            onTap: _noop,
            child: Text('The chosen option', style: body),
          ),
        ),
        const GalleryCase(label: 'StatCard row', child: _StatCardRow()),
        GalleryCase(
          label: 'accuracy card: a card, a large bar and a caption row',
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified,
                      size: 20,
                      color: AppColors.primaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.space2xs),
                    Expanded(
                      child: Text(
                        'Accuracy score',
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const CountBadge(label: '94%', tone: AppTone.primary),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceXs),
                const AppProgressBar(
                  value: 0.94,
                  size: AppProgressBarSize.large,
                  startLabel: '16 correct · 1 review',
                  endLabel: '2m 14s',
                  semanticLabel: 'Accuracy',
                ),
              ],
            ),
          ),
        ),
        const GalleryCase(
          label: 'InfoBanner: the daily-goal pill',
          child: InfoBanner(
            icon: Icons.local_cafe,
            message: 'Daily Buna brew ritual complete! Goal 100% met',
          ),
        ),
        // 020-dashboard-section-header: the dashboard's one coloured block,
        // and the quiet divider between sections in the path.
        for (final tone in [
          AppTone.primary,
          AppTone.secondary,
          AppTone.tertiary,
        ])
          GalleryCase(
            label: 'AppCard filled: ${tone.name} (the section header)',
            child: AppCard(
              tone: tone,
              filled: true,
              padding: AppCardPadding.compact,
              child: Text(
                'Family & People',
                style: AppTypography.labelLg.copyWith(color: tone.onFill),
              ),
            ),
          ),
        const GalleryCase(
          label: 'PathSectionDivider: where the next section begins',
          child: PathSectionDivider(title: 'Family & People'),
        ),
        GalleryCase(
          label: 'SectionHeader with an eyebrow and a text link',
          child: SectionHeader(
            eyebrow: 'Unit 2',
            title: 'Daily greetings',
            trailing: AppButton.text(label: 'See all', onPressed: _noop),
          ),
        ),
        GalleryCase(
          label: 'SnackBar: a short message, from the theme',
          child: Builder(
            builder: (context) => AppButton.secondary(
              label: 'Show a message',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Couldn't switch course. Please try again."),
                ),
              ),
            ),
          ),
        ),
        GalleryCase(
          label: 'ListRowGroup: chevron, switch, value and plain rows',
          child: ListRowGroup(
            children: [
              const ListRow(
                icon: Icons.person,
                tone: AppTone.primary,
                title: 'Profile',
                subtitle: 'Name, photo and email',
                onTap: _noop,
              ),
              SwitchRow(
                icon: Icons.volume_up,
                tone: AppTone.secondary,
                title: 'Sound effects',
                value: _sound,
                onChanged: (v) => setState(() => _sound = v),
              ),
              const SwitchRow(
                icon: Icons.notifications,
                title: 'Notifications (disabled)',
                value: false,
                onChanged: null,
              ),
              const ListRow(
                icon: Icons.download_done,
                title: 'Greetings pack',
                subtitle: 'Downloaded · 2.4 MB',
                trailing: _ValueText('v3'),
              ),
              const ListRow(
                icon: Icons.logout,
                tone: AppTone.tertiary,
                title: 'Sign out',
                onTap: _noop,
              ),
            ],
          ),
        ),
        GalleryCase(
          label: 'SelectableOptionCard: selected, unselected, disabled',
          child: Column(
            children: [
              for (final (i, title) in const [
                (0, 'Amharic'),
                (1, 'Afaan Oromo'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                  child: SelectableOptionCard(
                    leading: const Icon(Icons.translate),
                    title: title,
                    subtitle: 'Tap to choose',
                    selected: _chosen == i,
                    onTap: () => setState(() => _chosen = i),
                  ),
                ),
              const SelectableOptionCard(
                leading: Icon(Icons.translate),
                badgeLabel: 'COMING SOON',
                title: 'ትግርኛ Tigrinya',
                subtitle: 'Not available yet',
                enabled: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
