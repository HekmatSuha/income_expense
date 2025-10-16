import 'package:flutter/material.dart';
import 'package:flutter_native_timezone_updated_gradle/flutter_native_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app/router.dart';
import 'app/theme.dart';
import 'data/remote/firebase_service.dart';
import 'data/sync/sync_bootstrapper.dart';
import 'features/transactions/tx_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  tz.initializeTimeZones();
  try {
    final timezoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncBootstrapperProvider);
    ref.watch(recurringReminderBootstrapperProvider);
    ref.watch(recurringAutomationProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Income Expense',
      theme: appTheme,
      routerConfig: router,
    );
  }
}
