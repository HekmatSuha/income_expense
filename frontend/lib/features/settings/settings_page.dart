import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/firebase_service.dart';
import '../auth/auth_state.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _sendingVerification = false;
  bool _refreshingStatus = false;

  Future<void> _sendVerificationEmail(User user) async {
    setState(() {
      _sendingVerification = true;
    });
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Check your inbox.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send verification email: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingVerification = false;
        });
      }
    }
  }

  Future<void> _refreshUser(User user) async {
    setState(() {
      _refreshingStatus = true;
    });
    try {
      await user.reload();
      ref.invalidate(authStateChangesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh account: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseUserProvider);
    final guestMode = ref.watch(guestModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: guestMode || user == null
                ? const _GuestModeNotice()
                : _AccountDetails(
                    user: user,
                    onSendVerification: _sendingVerification
                        ? null
                        : () => _sendVerificationEmail(user),
                    onRefreshStatus:
                        _refreshingStatus ? null : () => _refreshUser(user),
                    sendingVerification: _sendingVerification,
                    refreshingStatus: _refreshingStatus,
                  ),
          ),
        ),
      ),
    );
  }
}

class _GuestModeNotice extends StatelessWidget {
  const _GuestModeNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.info_outline, size: 32),
            SizedBox(height: 16),
            Text(
              'Guest mode active',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Sign in to manage your account settings and email verification.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({
    required this.user,
    required this.onSendVerification,
    required this.onRefreshStatus,
    required this.sendingVerification,
    required this.refreshingStatus,
  });

  final User user;
  final VoidCallback? onSendVerification;
  final VoidCallback? onRefreshStatus;
  final bool sendingVerification;
  final bool refreshingStatus;

  @override
  Widget build(BuildContext context) {
    final email = user.email ?? 'Unknown';
    final verified = user.emailVerified;

    return ListView(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(email),
            subtitle: const Text('Email'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined),
                    const SizedBox(width: 12),
                    Text(
                      verified ? 'Email verified' : 'Email not verified',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  verified
                      ? 'Your email address has been verified. No further action is required.'
                      : 'Verify your email to unlock all features. We use your email address to secure your account.',
                ),
                const SizedBox(height: 16),
                if (!verified)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: onSendVerification,
                        icon: sendingVerification
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mail),
                        label: const Text('Resend verification email'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRefreshStatus,
                        icon: refreshingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('I have verified my email'),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onRefreshStatus,
                      icon: refreshingStatus
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Refresh status'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
