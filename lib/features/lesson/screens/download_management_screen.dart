import 'package:flutter/material.dart';

import '../../../shared/models/downloaded_pack_summary.dart';
import '../../../shared/services/lesson_pack_store.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// Story 005's download-management screen: lists downloaded lesson packs
/// with an approximate storage size and lets the user delete them.
///
/// Each pack is a card with an icon, title, size, and a quiet destructive
/// "Delete" action (confirmed via dialog before anything is removed).
class DownloadManagementScreen extends StatefulWidget {
  const DownloadManagementScreen({
    super.key,
    required this.lessonPackStore,
    required this.syncEngine,
  });

  final LessonPackStore lessonPackStore;
  final SyncEngine syncEngine;

  @override
  State<DownloadManagementScreen> createState() =>
      _DownloadManagementScreenState();
}

class _DownloadManagementScreenState extends State<DownloadManagementScreen> {
  late Future<List<DownloadedPackSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.lessonPackStore.listDownloadedPacks();
  }

  void _reload() {
    setState(() {
      _future = widget.lessonPackStore.listDownloadedPacks();
    });
  }

  Future<void> _confirmAndDelete(DownloadedPackSummary pack) async {
    final hasPending = await widget.syncEngine.hasPendingEntriesForLesson(
      pack.lessonId,
    );
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${pack.title}"?'),
        content: Text(
          hasPending
              ? "This lesson has progress that hasn't synced yet. "
                    'Deleting the download won\'t affect that pending '
                    'sync -- it only removes the offline copy.'
              : 'This removes the downloaded content and audio from your '
                    'device. Your synced progress is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.lessonPackStore.delete(pack.lessonId);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Manage Downloads')),
      body: SafeArea(
        child: FutureBuilder<List<DownloadedPackSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final packs = snapshot.data ?? const [];
            if (packs.isEmpty) {
              return Center(
                child: Text(
                  'No downloaded lessons yet.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              itemCount: packs.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.spaceSm),
              itemBuilder: (context, index) {
                final pack = packs[index];
                return _PackRow(
                  pack: pack,
                  onDelete: () => _confirmAndDelete(pack),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack, required this.onDelete});

  final DownloadedPackSummary pack;
  final VoidCallback onDelete;

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceMd,
        vertical: AppSpacing.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(color: AppColors.cardBorderDefault, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_done_rounded,
              color: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatSize(pack.approximateSizeBytes),
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ],
      ),
    );
  }
}
