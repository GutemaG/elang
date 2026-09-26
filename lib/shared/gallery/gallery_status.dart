import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tone.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_status.dart';
import '../widgets/course_glyph.dart';
import '../widgets/path_node.dart';
import 'component_gallery.dart';

void _noop() {}

/// Pills, badges, progress, icon badges, the spinner, the empty, error and
/// loading states, the sync messages on `InfoBanner`, carousel dots, choice
/// chips, path nodes and course glyphs.
class StatusGallerySection extends StatefulWidget {
  const StatusGallerySection({super.key});

  @override
  State<StatusGallerySection> createState() => _StatusGallerySectionState();
}

class _StatusGallerySectionState extends State<StatusGallerySection> {
  double _progress = 0.3;
  int _page = 0;
  String _speak = 'English';

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'Status and feedback',
      note:
          'Stats, progress and "nothing here" only ever look like this. '
          'Numbers are grouped; each piece reads as one phrase.',
      children: [
        const GalleryCase(
          label: 'StatPill: streak, beans, XP, Amole (12,340 formats)',
          child: Wrap(
            spacing: AppSpacing.spaceXs,
            runSpacing: AppSpacing.spaceXs,
            children: [
              StatPill(kind: StatKind.streak, value: 6),
              StatPill(kind: StatKind.beans, value: 3, max: 5),
              StatPill(kind: StatKind.xp, value: 12340),
              StatPill(kind: StatKind.amole, value: 420),
            ],
          ),
        ),
        const GalleryCase(
          label: 'CountBadge (neutral, toned) and RibbonBadge',
          child: Wrap(
            spacing: AppSpacing.spaceXs,
            runSpacing: AppSpacing.spaceXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CountBadge(label: '3/5 Completed', icon: Icons.flag),
              CountBadge(
                label: '0 / 5',
                icon: Icons.local_cafe,
                tone: AppTone.tertiary,
              ),
              RibbonBadge(label: '+1 TODAY'),
              RibbonBadge(label: 'NEW', tone: AppTone.primary),
            ],
          ),
        ),
        GalleryCase(
          label: 'AppProgressBar: tap to move it (eases, then settles)',
          child: GestureDetector(
            onTap: () => setState(
              () => _progress = _progress > 0.8 ? 0.1 : _progress + 0.3,
            ),
            child: AppProgressBar(
              value: _progress,
              gradient: true,
              startLabel: 'Unit progress',
              endLabel: '${(_progress * 100).round()}%',
              semanticLabel: 'Unit progress',
            ),
          ),
        ),
        const GalleryCase(
          label: 'empty, a sliver, flat secondary, full large',
          child: Column(
            children: [
              AppProgressBar(value: 0),
              SizedBox(height: AppSpacing.spaceSm),
              AppProgressBar(value: 0.02),
              SizedBox(height: AppSpacing.spaceSm),
              AppProgressBar(value: 0.5, tone: AppTone.secondary),
              SizedBox(height: AppSpacing.spaceSm),
              AppProgressBar(value: 1, size: AppProgressBarSize.large),
            ],
          ),
        ),
        GalleryCase(
          label: 'IconBadge in every tone, and square',
          child: Wrap(
            spacing: AppSpacing.spaceSm,
            runSpacing: AppSpacing.spaceSm,
            children: [
              for (final tone in AppTone.values)
                IconBadge(icon: Icons.local_cafe, tone: tone),
              const IconBadge(
                icon: Icons.hourglass_top,
                tone: AppTone.tertiary,
                square: true,
              ),
            ],
          ),
        ),
        const GalleryCase(
          label: 'AppSpinner, regular and small',
          child: Row(
            children: [
              AppSpinner(),
              SizedBox(width: AppSpacing.spaceMd),
              AppSpinner.small(),
            ],
          ),
        ),
        const GalleryCase(
          label: 'InfoBanner: every sync status',
          child: Column(
            children: [
              InfoBanner(
                icon: Icons.sync,
                tone: AppTone.primary,
                message: 'Syncing your offline progress...',
              ),
              SizedBox(height: AppSpacing.spaceXs),
              InfoBanner(
                icon: Icons.cloud_off,
                tone: AppTone.neutral,
                message: 'Offline -- downloaded lessons available',
              ),
              SizedBox(height: AppSpacing.spaceXs),
              InfoBanner(
                icon: Icons.cloud_off,
                tone: AppTone.tertiary,
                message: 'Offline -- nothing downloaded',
              ),
              SizedBox(height: AppSpacing.spaceXs),
              InfoBanner(
                icon: Icons.sync_problem,
                tone: AppTone.tertiary,
                message: 'Sync failed -- retrying...',
              ),
              SizedBox(height: AppSpacing.spaceXs),
              InfoBanner(
                icon: Icons.sync_problem,
                tone: AppTone.tertiary,
                emphasis: true,
                message:
                    'Sync failed -- retrying... (unsynced for 30+ days -- '
                    'please reconnect soon)',
              ),
            ],
          ),
        ),
        const GalleryCase(
          label: 'InfoBanner with an action (sign-in error and Retry)',
          child: InfoBanner(
            icon: Icons.info_outline,
            message: 'Something went wrong — try again',
            action: AppButton.secondary(
              label: 'Retry',
              onPressed: _noop,
              leading: Icon(Icons.refresh, size: 18),
              expand: false,
              size: AppButtonSize.compact,
            ),
          ),
        ),
        GalleryCase(
          label: 'PageDots: tap to move to the next page',
          child: GestureDetector(
            onTap: () => setState(() => _page = (_page + 1) % 3),
            child: Center(child: PageDots(count: 3, index: _page)),
          ),
        ),
        GalleryCase(
          label: 'ChoiceChip, styled by the theme ("I speak")',
          child: Wrap(
            spacing: AppSpacing.spaceXs,
            runSpacing: AppSpacing.spaceXs,
            children: [
              for (final name in const ['English', 'አማርኛ', 'Afaan Oromoo'])
                ChoiceChip(
                  label: Text(name),
                  selected: _speak == name,
                  onSelected: (_) => setState(() => _speak = name),
                ),
            ],
          ),
        ),
        const GalleryCase(
          label: 'PathNode: locked, active, part-way, completed with a crown',
          child: Wrap(
            spacing: AppSpacing.spaceXs,
            runSpacing: AppSpacing.spaceMd,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              PathNode(
                state: PathNodeState.locked,
                label: 'Numbers',
                semanticLabel: 'Numbers, locked',
              ),
              PathNode(
                state: PathNodeState.active,
                label: 'Family',
                semanticLabel: 'Family, active, tap to start',
                onTap: _noop,
              ),
              PathNode(
                state: PathNodeState.active,
                label: 'Food · 1/2',
                semanticLabel:
                    'Food, active, tap to start, 1 of 2 lessons done',
                progress: 0.5,
                onTap: _noop,
              ),
              PathNode(
                state: PathNodeState.completed,
                label: 'Greetings',
                semanticLabel: 'Greetings, completed, tap to replay',
                crownLevel: 2,
                onTap: _noop,
              ),
            ],
          ),
        ),
        const GalleryCase(
          label: 'CourseGlyph: Amharic, Afaan Oromo, and the active ring',
          child: Row(
            children: [
              CourseGlyph(languageCode: 'am', size: 44),
              SizedBox(width: AppSpacing.spaceSm),
              CourseGlyph(languageCode: 'om', size: 44),
              SizedBox(width: AppSpacing.spaceSm),
              CourseGlyph(languageCode: 'am', size: 44, selected: true),
            ],
          ),
        ),
        const GalleryCase(
          label: 'EmptyState',
          child: AppCard(
            child: EmptyState(
              icon: Icons.download,
              title: 'No downloads yet',
              message:
                  'Download a lesson from the path to learn without a '
                  'connection.',
              action: AppButton.secondary(
                label: 'Go to lessons',
                onPressed: _noop,
                expand: false,
              ),
            ),
          ),
        ),
        const GalleryCase(
          label: 'ErrorState with a retry',
          child: AppCard(
            child: ErrorState(
              title: "Couldn't load this lesson",
              message: 'Check your connection and try again.',
              onRetry: _noop,
            ),
          ),
        ),
        const GalleryCase(
          label: 'LoadingState and LoadingState.still (settles)',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppCard(child: LoadingState(message: 'Loading lesson')),
              ),
              SizedBox(width: AppSpacing.gutterMobile),
              Expanded(child: AppCard(child: LoadingState.still())),
            ],
          ),
        ),
      ],
    );
  }
}
