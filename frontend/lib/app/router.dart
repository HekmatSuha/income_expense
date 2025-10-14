import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/remote/firebase_service.dart';
import '../features/auth/auth_state.dart';
import '../features/auth/sign_in_page.dart';
import '../features/settings/settings_page.dart';
import '../features/transactions/transactions_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefresh(ref);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = ref.read(firebaseUserProvider);
      final guestMode = ref.read(guestModeProvider);
      final loggingIn = state.matchedLocation == '/login';
      final atSettings = state.matchedLocation == '/settings';

      if (guestMode) {
        if (loggingIn || atSettings) {
          return '/';
        }
        return null;
      }

      if (user == null) {
        return loggingIn ? null : '/login';
      }

      if (!user.emailVerified && !atSettings) {
        return '/settings';
      }

      if (loggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, st) => const SignInPage()),
      GoRoute(path: '/', builder: (ctx, st) => const TransactionsPage()),
      GoRoute(path: '/settings', builder: (ctx, st) => const SettingsPage()),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _authSub = _ref.listen<User?>(
      firebaseUserProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
    _guestSub = _ref.listen<bool>(
      guestModeProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<User?> _authSub;
  late final ProviderSubscription<bool> _guestSub;

  @override
  void dispose() {
    _authSub.close();
    _guestSub.close();
    super.dispose();
  }
}
