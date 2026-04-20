// lib/account_button.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';

import 'auth_gate.dart';
import 'auth_config.dart';
import 'app_locale.dart'; // NEW: for t()

class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  Future<void> _openAccountSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => const _AccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: t('Account', '账户', 'Cuenta'),
      icon: const Icon(Icons.account_circle),
      onPressed: () => _openAccountSheet(context),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  /// 🔥 FULL SIGN OUT (Firebase + Google + all providers)
  Future<void> _fullSignOut(BuildContext context) async {
    await FirebaseUIAuth.signOut(context: context); // key line

    Navigator.pop(context); // close bottom sheet

    // Go back to login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthGate(clientId: kGoogleWebClientId),
      ),
      (route) => false,
    );
  }

  /// 🔁 “Switch account” → same as full sign out
  Future<void> _switchAccount(BuildContext context) async {
    await _fullSignOut(context);
  }

  /// 🚪 From guest mode → go to login page
  void _goToSignIn(BuildContext context) {
    Navigator.pop(context); // close bottom sheet
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthGate(clientId: kGoogleWebClientId),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
        left: 16,
        right: 16,
      ),
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final loggedIn = user != null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),

              // user info row
              Row(
                children: [
                  const Icon(Icons.account_circle, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loggedIn
                          ? (user.email ??
                              t('Signed in', '已登录', 'Sesión iniciada'))
                          : t(
                              'Guest mode (not signed in)',
                              '访客模式（未登录）',
                              'Modo invitado (no has iniciado sesión)',
                            ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              if (loggedIn) ...[
                // ⭐ SWITCH ACCOUNT
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                      t('Switch account', '切换账户', 'Cambiar de cuenta'),
                    ),
                    onPressed: () => _switchAccount(context),
                  ),
                ),
                const SizedBox(height: 8),

                // SIGN OUT
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: Text(
                      t('Sign out', '退出登录', 'Cerrar sesión'),
                    ),
                    onPressed: () => _fullSignOut(context),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    t(
                      "You are using guest mode.\nSign in to sync your presets and settings.",
                      "你正在使用访客模式。\n登录以同步你的预设和设置。",
                      "Estás en modo invitado.\nInicia sesión para sincronizar tus presets y ajustes.",
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: Text(
                      t('Sign in', '登录', 'Iniciar sesión'),
                    ),
                    onPressed: () => _goToSignIn(context),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
