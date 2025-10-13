import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/remote/firebase_service.dart';
import '../features/auth/sign_in_page.dart';
import '../features/transactions/transactions_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: _RouterRefreshStream(ref.watch(authStateChangesProvider.stream)),
    redirect: (context, state) {
      final user = ref.read(firebaseUserProvider);
      final loggingIn = state.matchedLocation == '/login';
      if (user == null) {
        return loggingIn ? null : '/login';
      } else {
        return loggingIn ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, st) => const SignInPage()),
      GoRoute(path: '/', builder: (ctx, st) => const TransactionsPage()),
    ],
  );
});

class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
