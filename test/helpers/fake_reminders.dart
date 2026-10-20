import 'package:tidypics/features/reminders/application/reminders.dart';

/// Faux rappels : on note ce qui serait programmé.
class FakeReminderScheduler implements ReminderScheduler {
  bool permission = true;
  String? scheduledBody;
  int cancels = 0;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleWeekly({
    required String title,
    required String body,
  }) async => scheduledBody = body;

  @override
  Future<void> cancel() async {
    cancels++;
    scheduledBody = null;
  }
}
