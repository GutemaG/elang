import 'package:flutter/material.dart';

import '../../../shared/models/downloaded_pack_summary.dart';
import '../../../shared/services/lesson_pack_store.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';

/// Story 005's download-management screen: lists downloaded lesson packs
/// with an approximate storage size and lets the user delete them.
///
/// Drawn on the design library (018-mobile-design-system, bolt 049): each
/// pack is a row on one card with a delete button, deleting is confirmed in
/// the library dialog with a destructive primary, and an empty list is an
/// [EmptyState].
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
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete "${pack.title}"?',
      message: hasPending
          ? "This lesson has progress that hasn't synced yet. "
                'Deleting the download won\'t affect that pending '
                'sync -- it only removes the offline copy.'
          : 'This removes the downloaded content and audio from your '
                'device. Your synced progress is not affected.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed != true) return;
    await widget.lessonPackStore.delete(pack.lessonId);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DownloadedPackSummary>>(
      future: _future,
      builder: (context, snapshot) {
        final done = snapshot.connectionState == ConnectionState.done;
        final packs = snapshot.data ?? const <DownloadedPackSummary>[];
        return AppPage(
          topBar: AppTopBar(
            leading: Navigator.of(context).canPop()
                ? AppIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
            title: 'Manage Downloads',
          ),
          // Loading and the empty state sit in the middle of the page; the
          // list scrolls.
          scrollable: done && packs.isNotEmpty,
          body: !done
              ? const Center(child: LoadingState())
              : packs.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.download_for_offline_outlined,
                      title: 'No downloaded lessons yet.',
                      message:
                          'Lessons you download from the path show up '
                          'here, ready to play offline.',
                    ),
                  ),
                )
              : ListRowGroup(
                  children: [
                    for (final pack in packs)
                      _PackRow(
                        pack: pack,
                        onDelete: () => _confirmAndDelete(pack),
                      ),
                  ],
                ),
        );
      },
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
    return ListRow(
      icon: Icons.download_done_rounded,
      tone: AppTone.primary,
      title: pack.title,
      subtitle:
          '${pack.courseTitle} · ${_formatSize(pack.approximateSizeBytes)}',
      trailing: AppIconButton(
        icon: Icons.delete_outline_rounded,
        tooltip: 'Delete "${pack.title}"',
        onPressed: onDelete,
      ),
    );
  }
}
