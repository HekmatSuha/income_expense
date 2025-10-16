import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app_database.dart';

class ReminderService {
  ReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  final Set<String> _scheduled = <String>{};

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );
    await _plugin.initialize(settings);
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    final darwinPlugin =
        _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    await darwinPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> syncRecurringTemplates(List<Transaction> templates) async {
    await ensureInitialized();
    final keep = <String>{};
    for (final template in templates) {
      keep.add(template.id);
      if (template.reminderAt == null ||
          template.recurrencePaused == true ||
          template.nextOccurrence == null) {
        await _cancelReminder(template.id);
        continue;
      }
      if (!template.reminderAt!.isAfter(DateTime.now())) {
        await _cancelReminder(template.id);
        continue;
      }
      await _scheduleReminder(template);
    }
    final stale = _scheduled.difference(keep).toList();
    for (final id in stale) {
      await _cancelReminder(id);
    }
  }

  Future<void> _scheduleReminder(Transaction template) async {
    final reminder = template.reminderAt!;
    final notificationId = _notificationId(template.id);
    await _plugin.cancel(notificationId);
    final tzTime = tz.TZDateTime.from(reminder, tz.local);
    final currency = NumberFormat.simpleCurrency();
    final amountLabel = currency.format(template.amount);
    final title = template.type == 'income'
        ? 'Upcoming income reminder'
        : 'Upcoming expense reminder';
    final body = '${template.type == 'income' ? 'Income' : 'Expense'} of '
        '$amountLabel is scheduled.';
    const androidDetails = AndroidNotificationDetails(
      'recurring_transactions',
      'Recurring transactions',
      channelDescription: 'Reminders for recurring transactions',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const macDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macDetails,
    );
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      tzTime,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: template.id,
    );
    _scheduled.add(template.id);
  }

  Future<void> _cancelReminder(String id) async {
    final notificationId = _notificationId(id);
    await _plugin.cancel(notificationId);
    _scheduled.remove(id);
  }

  int _notificationId(String id) => id.hashCode & 0x7fffffff;
}

final flutterLocalNotificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  final plugin = ref.watch(flutterLocalNotificationsPluginProvider);
  final service = ReminderService(plugin);
  return service;
});
