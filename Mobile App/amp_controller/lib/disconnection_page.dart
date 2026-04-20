import 'package:flutter/material.dart';

import 'ble_connection.dart';
import 'connection_page.dart';
import 'transitions.dart';
import 'app_locale.dart';

class DisconnectingPage extends StatefulWidget {
  const DisconnectingPage({super.key});

  @override
  State<DisconnectingPage> createState() => _DisconnectingPageState();
}

class _DisconnectingPageState extends State<DisconnectingPage> {
  @override
  void initState() {
    super.initState();
    _disconnectAndGoBack();
  }

  Future<void> _disconnectAndGoBack() async {
    BleController.instance.reconnectEnabled = false;
    BleController.instance.suppressNextAutoScan = true;

    try {
      await BleController.instance.disconnect();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      FadePageRoute(child: const ConnectionPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                t(
                  'Disconnecting…',
                  '正在断开连接…',
                  'Desconectando…',
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}