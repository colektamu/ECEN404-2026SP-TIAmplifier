import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
// ignore: unused_import
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';

import 'firebase_options.dart';
import 'auth_gate.dart';
import 'auth_config.dart';

import 'locale_controller.dart';
import 'app_locale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseUIAuth.configureProviders([
    EmailAuthProvider(),
    GoogleProvider(clientId: kGoogleWebClientId),
  ]);

  runApp(const AmpApp());
}

class AmpApp extends StatelessWidget {
  const AmpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (context, _) {
        final locale = LocaleController.instance.locale;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: t('Amp Controller', '功放控制器', 'Controlador de amplificador'),
          theme: ThemeData(primarySwatch: Colors.blue),

          // ✅ drives Firebase UI language
          locale: locale,

          // ✅ tell Flutter/Firebase UI which locales you support
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
            Locale('es'),
          ],

          // ✅ REQUIRED for Firebase UI + Flutter built-in localization
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,

            FirebaseUILocalizations.delegate,
          ],

          // ✅ keep this: forces AuthGate tree to rebuild on language change
          home: AuthGate(
            key: ValueKey(locale.languageCode),
            clientId: kGoogleWebClientId,
          ),
        );
      },
    );
  }
}
