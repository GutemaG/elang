/// One row of the download-management screen
/// (010-offline-caching-and-sync-ui, story 005): a downloaded lesson pack's
/// identity plus its approximate on-device storage footprint.
class DownloadedPackSummary {
  const DownloadedPackSummary({
    required this.lessonId,
    required this.title,
    required this.approximateSizeBytes,
  });

  final String lessonId;
  final String title;
  final int approximateSizeBytes;
}
