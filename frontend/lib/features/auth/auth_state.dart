import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/firebase_service.dart';

/// Controls whether the app should bypass Firebase authentication and run in a
/// local-only guest mode. When enabled, the rest of the app behaves as if a
/// user with a deterministic identifier is signed in so that the local Drift
/// database continues to function.
final guestModeProvider = StateProvider<bool>((ref) => false);

/// Resolves the active user identifier, preferring a signed-in Firebase user
/// when available. When guest mode is enabled, a stable local identifier is
/// returned instead so the repositories can continue to read/write data.
final effectiveUserIdProvider = Provider<String?>((ref) {
  final guestMode = ref.watch(guestModeProvider);
  if (guestMode) {
    return 'guest-user';
  }
  final firebaseUser = ref.watch(firebaseUserProvider);
  return firebaseUser?.uid;
});
