/// One row of the download-management screen
/// (010-offline-caching-and-sync-ui, story 005): a downloaded lesson pack's
/// identity plus its approximate on-device storage footprint.
class DownloadedPackSummary {
  const DownloadedPackSummary({
    required this.lessonId,
    required this.title,
    required this.approximateSizeBytes,
    this.courseTitle = legacyPackCourseTitle,
  });

  /// Packs downloaded before courses existed have no course recorded; they
  /// were all English to Amharic (010-multi-language-courses, story 003).
  static const legacyPackCourseTitle = 'English to Amharic';

  final String lessonId;
  final String title;
  final int approximateSizeBytes;

  /// The course this pack belongs to, for the download-management screen.
  final String courseTitle;
}
