import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../remote/firebase_service.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/tx_repository.dart';

final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

final syncBootstrapperProvider = Provider<_SyncBootstrapper>((ref) {
  final bootstrapper = _SyncBootstrapper(ref);
  ref.onDispose(bootstrapper.dispose);
  return bootstrapper;
});

class _SyncBootstrapper {
  _SyncBootstrapper(this.ref) {
    _listenForAuthChanges();
    _listenForConnectivity();
  }

  final Ref ref;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  void _listenForAuthChanges() {
    ref.listen<User?>(firebaseUserProvider, (prev, next) {
      final user = next;
      if (user != null) {
        _triggerFullSync(user.uid);
      }
    }, fireImmediately: true);
  }

  void _listenForConnectivity() {
    final connectivity = ref.read(connectivityProvider);
    _connectivitySub = connectivity.onConnectivityChanged.listen((status) {
      if (status == ConnectivityResult.none) return;
      final user = ref.read(firebaseUserProvider);
      if (user != null) {
        _triggerFullSync(user.uid);
      }
    });
  }

  void _triggerFullSync(String userId) {
    ref.read(txRepositoryProvider).triggerSync(userId);
    ref.read(categoryRepositoryProvider).triggerSync(userId);
    ref.read(accountRepositoryProvider).triggerSync(userId);
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
