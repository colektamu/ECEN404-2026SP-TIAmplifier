// lib/language_button.dart
import 'package:flutter/material.dart';

import 'locale_controller.dart';
import 'app_locale.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: t('Change language', '切换语言', 'Cambiar idioma'),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          builder: (context) => const _LanguageSheet(),
        );
      },
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t('Choose Language', '选择语言', 'Elegir idioma'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: const Text('🇺🇸', style: TextStyle(fontSize: 26)),
            title: const Text('English'),
            onTap: () {
              LocaleController.instance.setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Text('🇨🇳', style: TextStyle(fontSize: 26)),
            title: const Text('中文'),
            onTap: () {
              LocaleController.instance.setLocale(const Locale('zh'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Text('🇪🇸', style: TextStyle(fontSize: 26)),
            title: const Text('Español'),
            onTap: () {
              LocaleController.instance.setLocale(const Locale('es'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
