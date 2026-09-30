import 'package:elang/shared/services/reminders/reminder_plan.dart';
import 'package:elang/shared/services/reminders/reminder_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

/// Records what the daily reminder would schedule, without the plugin
/// (021-daily-reminder). Tests load the time zone data themselves.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({
    this.location,
    this.permitted = true,
    this.supported = true,
    this.grantOnRequest = true,
  });

  /// The phone's zone; `null` means UTC.
  tz.Location? location;
  bool permitted;

  @override
  bool supported;

  /// What the learner answers when asked.
  bool grantOnRequest;
  int requestCount = 0;
  int openSettingsCount = 0;

  /// What is scheduled now.
  List<PlannedReminder> scheduled = const [];
  int cancelAllCount = 0;

  @override
  Future<tz.Location> localLocation() async => location ?? tz.UTC;

  @override
  Future<bool> isPermitted() async => permitted;

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    if (grantOnRequest) permitted = true;
    return permitted;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCount++;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    scheduled = List.unmodifiable(reminders);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled = const [];
  }
}
