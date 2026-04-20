import 'package:flutter/material.dart';
import 'app_locale.dart'; // <-- add this for t()

class LoadingPage extends StatefulWidget {
  const LoadingPage({
    super.key,
    required this.nextPage,
    this.message,
  });

  /// The page to navigate to after the short loading period.
  final Widget nextPage;

  /// Optional message shown under the title.
  final String? message;

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();

    // Short delay so user can see the loading screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextPage),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon inside a soft card
              Card(
                elevation: 8,
                shadowColor: colorScheme.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: SizedBox(
                    height: 80,
                    width: 80,
                    child: Image.asset(
                      'assets/icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // App name (localized)
              Text(
                t(
                  'Amp Controller',
                  '功放控制器',
                  'Controlador de amplificador',
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Message (custom or default, localized)
              Text(
                widget.message ??
                    t(
                      'Loading your settings…',
                      '正在加载你的设置…',
                      'Cargando tu configuración…',
                    ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),

              // Loader
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
