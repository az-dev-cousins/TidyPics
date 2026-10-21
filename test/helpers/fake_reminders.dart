import 'package:tidypics/features/reminders/application/reminders.dart';

/// Faux rappels : on note ce qui serait programmé.
class FakeReminderScheduler implements ReminderScheduler {
  bool permission = true;
  List<ScheduledText> scheduled = const [];
  int cancels = 0;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleAll(List<ScheduledText> reminders) async =>
      scheduled = reminders;

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = const [];
  }
}
