import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'account_button.dart';
import 'control_screen.dart';
import 'app_locale.dart';
import 'locale_controller.dart';

import 'ble_connection.dart';
import 'ble_uuids.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  bool _isBtOn = true;
  bool _scanning = false;
  bool _connecting = false;

  String _status = '';
  ScanResult? _best;

  final String mcuNameHint = "TIAmpEsp";

  @override
  void initState() {
    super.initState();

    LocaleController.instance.addListener(_onLocaleChange);

    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      final on = state == BluetoothAdapterState.on;
      if (!mounted) return;
      setState(() {
        _isBtOn = on;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (BleController.instance.suppressNextAutoScan) {
        BleController.instance.suppressNextAutoScan = false;

        if (!mounted) return;
        setState(() {
          _status = t(
            'Disconnected. Tap Retry to scan again.',
            '已断开连接。点击重试重新扫描。',
            'Desconectado. Pulsa Reintentar para escanear de nuevo.',
          );
        });
        return;
      }

      await _initializeAndScan();
    });
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocaleChange);
    _adapterSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeAndScan() async {
    final ok = await _ensureBlePermissions();
    if (!ok) return;
    await _startAutoScan();
  }

  Future<bool> _ensureBlePermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationGranted =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    final ok = scanGranted && connectGranted;

    if (!ok && mounted) {
      setState(() {
        _status = t(
          'Bluetooth permission denied. Please allow Nearby devices/Bluetooth and Location, then retry.',
          '蓝牙权限被拒绝。请允许“附近设备/蓝牙”和定位权限后重试。',
          'Permiso de Bluetooth denegado. Permite dispositivos cercanos/Bluetooth y ubicación, luego reintenta.',
        );
      });
      return false;
    }

    if (!locationGranted && mounted) {
      setState(() {
        _status = t(
          'Bluetooth permissions granted. If scan still fails, also enable Location/GPS.',
          '蓝牙权限已授予。如果仍扫描失败，请同时打开定位/GPS。',
          'Permisos Bluetooth concedidos. Si el escaneo sigue fallando, activa también Ubicación/GPS.',
        );
      });
    }

    return true;
  }

  Future<void> _stopScanSafe() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  bool _advertisesOurService(ScanResult r) {
    final adv = r.advertisementData.serviceUuids;
    return adv.any((g) => g == BleUuids.service);
  }

  bool _nameLooksLikeMcu(ScanResult r) {
    final n = r.device.platformName;
    if (n.isEmpty) return false;
    return n.toLowerCase().contains(mcuNameHint.toLowerCase());
  }

  ScanResult? _pickBest(List<ScanResult> list) {
    final matches = list.where((r) {
      return _nameLooksLikeMcu(r) || _advertisesOurService(r);
    }).toList();

    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.rssi.compareTo(a.rssi));
    return matches.first;
  }

  Future<void> _startAutoScan() async {
    if (_scanning || _connecting) return;

    final ok = await _ensureBlePermissions();
    if (!ok) return;

    if (!_isBtOn) {
      setState(() {
        _status = t(
          'Bluetooth is OFF. Turn it on, then retry.',
          '蓝牙已关闭，请打开后重试。',
          'Bluetooth está apagado. Enciéndelo y reintenta.',
        );
      });
      return;
    }

    setState(() {
      _status = t(
        'Scanning for MCU…',
        '正在扫描 MCU…',
        'Buscando MCU…',
      );
      _scanning = true;
      _connecting = false;
      _best = null;
    });

    await _stopScanSafe();

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      _scanSub = FlutterBluePlus.scanResults.listen((list) async {
        if (_connecting) return;

        for (final r in list) {
          debugPrint(
            'BLE found -> id=${r.device.remoteId}, '
            'name=${r.device.platformName}, '
            'uuids=${r.advertisementData.serviceUuids}, '
            'rssi=${r.rssi}',
          );
        }

        final best = _pickBest(list);
        if (best == null) return;

        _best = best;
        _connecting = true;

        await _stopScanSafe();

        if (!mounted) return;
        setState(() {
          _status = t(
            'Found MCU. Connecting…',
            '已找到 MCU，正在连接…',
            'MCU encontrado. Conectando…',
          );
        });

        try {
          await BleController.instance.connect(best.device);

          // Real BLE connection must disable skip mode
          BleController.instance.skipMode = false;

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ControlScreen(),
            ),
          );
        } catch (e) {
          debugPrint('BLE connect failed: $e');

          if (!mounted) return;
          setState(() {
            _status = t(
              'Connect failed: $e',
              '连接失败：$e',
              'Conexión fallida: $e',
            );
            _connecting = false;
          });
        }
      });

      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('BLE scan error: $e');

      if (!mounted) return;
      setState(() {
        _status = t(
          'Scan error: $e',
          '扫描错误：$e',
          'Error de escaneo: $e',
        );
      });
    } finally {
      await _stopScanSafe();

      if (!mounted) return;
      setState(() {
        _scanning = false;
        if (!_connecting && (_best == null)) {
          _status = t(
            'No MCU found. Check Bluetooth, Nearby devices, Location/GPS, and MCU advertising, then Retry.',
            '未找到 MCU。请检查蓝牙、附近设备权限、定位/GPS 和 MCU 广播后重试。',
            'No se encontró el MCU. Revisa Bluetooth, permisos de dispositivos cercanos, ubicación/GPS y advertising del MCU, luego reintenta.',
          );
        }
      });
    }
  }

  void _skipConnection() {
    BleController.instance.enableSkipMode();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ControlScreen(),
      ),
    );
  }

  Future<void> _showBtHint() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Please make sure Bluetooth is ON, Nearby devices permission is allowed, and Location/GPS is enabled.',
            '请确保蓝牙已打开、附近设备权限已允许，并且定位/GPS 已开启。',
            'Asegúrate de que Bluetooth esté activado, permisos de dispositivos cercanos permitidos y ubicación/GPS activados.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('Connect to MCU', '连接 MCU', 'Conectar MCU')),
            actions: const [AccountButton()],
          ),
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      _isBtOn
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _isBtOn ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      _isBtOn
                          ? t('Bluetooth ON', '蓝牙已开启', 'Bluetooth activado')
                          : t('Bluetooth OFF', '蓝牙已关闭', 'Bluetooth desactivado'),
                    ),
                    subtitle: Text(
                      t(
                        'Auto-scan and connect to "TIAmpEsp".',
                        '自动扫描并连接你的 "TIAmpEsp"。',
                        'Análisis automático y conexión a "TIAmpEsp".',
                      ),
                    ),
                    onTap: _showBtHint,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (_scanning || _connecting)
                  const Center(child: CircularProgressIndicator()),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: (_scanning || _connecting) ? null : _startAutoScan,
                  icon: const Icon(Icons.refresh),
                  label: Text(t('Retry', '重试', 'Reintentar')),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _skipConnection,
                  child: Text(t('Skip Connection', '跳过连接', 'Saltar conexión')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}