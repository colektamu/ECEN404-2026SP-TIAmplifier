// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connection_page.dart';
import 'loading_page.dart';
import 'app_locale.dart';
import 'locale_controller.dart';
import 'language_button.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.clientId});

  final String clientId;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _rememberEmail = false;
  // ignore: unused_field
  String? _savedEmail;
  // ignore: unused_field
  bool _prefsLoaded = false;

  late final VoidCallback _localeListener;

  @override
  void initState() {
    super.initState();
    // 🔁 Rebuild AuthGate when language changes
    _localeListener = () => setState(() {});
    LocaleController.instance.addListener(_localeListener);

    _loadRememberedEmail();
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_localeListener);
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_email') ?? false;
    String? email;
    if (remember) {
      email = prefs.getString('saved_email');
    }
    setState(() {
      _rememberEmail = remember;
      _savedEmail = email;
      _prefsLoaded = true;
    });
  }

  Future<void> _saveRememberSettings({String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_email', _rememberEmail);
    if (_rememberEmail && email != null && email.isNotEmpty) {
      await prefs.setString('saved_email', email);
    } else {
      await prefs.remove('saved_email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Already signed in → show loading, then go to connection page
        if (snapshot.hasData) {
          return LoadingPage(
            message: t(
              'Signing you in…',
              '正在为你登录…',
              'Iniciando sesión…',
            ),
            nextPage: const ConnectionPage(),
          );
        }

        // Not signed in → sign-in screen
        return Scaffold(
          appBar: AppBar(
            title: Text(
              t('Welcome', '欢迎', 'Bienvenido'),
            ),
            actions: const [
              LanguageButton(),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SignInScreen(
                providers: [
                  EmailAuthProvider(),
                  GoogleProvider(clientId: widget.clientId),
                ],

                // Only handle errors + remember email here
                actions: [
                  AuthStateChangeAction<AuthFailed>((context, state) {
                    debugPrint('AUTH ERROR: ${state.exception}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t(
                            'Login failed. Please try again.',
                            '登录失败，请重试。',
                            'Error al iniciar sesión. Inténtalo de nuevo.',
                          ),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }),
                  AuthStateChangeAction<SignedIn>((context, state) async {
                    final email = state.user?.email;
                    await _saveRememberSettings(email: email);
                  }),
                ],

                // HEADER (icon + title)
                headerBuilder: (context, constraints, shrinkOffset) {
                  final media = MediaQuery.of(context);
                  final keyboardOpen = media.viewInsets.bottom > 0;

                  if (keyboardOpen) {
                    return const SizedBox.shrink();
                  }

                  final double maxHeaderHeight =
                      constraints.maxHeight.isFinite
                          ? constraints.maxHeight
                          : 100.0;

                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeaderHeight),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 72,
                              child: Image.asset(
                                'assets/icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(
                                'Amp Controller',
                                '功放控制器',
                                'Controlador de amplificador',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },

                // SUBTITLE
                subtitleBuilder: (context, action) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: action == AuthAction.signIn
                        ? Text(
                            t(
                              'Please sign in to continue.',
                              '请登录以继续。',
                              'Inicia sesión para continuar.',
                            ),
                            textAlign: TextAlign.center,
                          )
                        : Text(
                            t(
                              'Create an account to sync your presets.',
                              '创建账号以同步你的预设。',
                              'Crea una cuenta para sincronizar tus presets.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                  );
                },

                // FOOTER
                footerBuilder: (context, action) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t(
                            'By signing in, you agree to our terms and conditions.',
                            '登录即表示你同意我们的条款与条件。',
                            'Al iniciar sesión aceptas nuestros términos y condiciones.',
                          ),
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const ConnectionPage(),
                              ),
                            );
                          },
                          child: Text(
                            t(
                              'Continue as guest',
                              '以访客身份继续',
                              'Continuar como invitado',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },

                // SIDE (desktop/web)
                sideBuilder: (context, shrinkOffset) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.graphic_eq,
                          size: 120,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          t(
                            'Control your amp,\nmanage presets,\nand play the piano.',
                            '控制功放、管理预设，\n还可以弹钢琴。',
                            'Controla tu amplificador,\nadministra presets\ny toca el piano.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
