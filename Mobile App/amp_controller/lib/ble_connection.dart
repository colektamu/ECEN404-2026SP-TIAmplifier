import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_uuids.dart';

class BleController {
  BleController._();
  static final BleController instance = BleController._();

  BluetoothDevice? device;
  BluetoothCharacteristic? dataInChar;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  Stream<BluetoothConnectionState>? get connectionStateStream =>
      device?.connectionState;

  bool get isReady => device != null && dataInChar != null;

  bool reconnectEnabled = true;
  bool isWriting = false;
  bool skipMode = false;
  bool _isConnecting = false;
  bool suppressNextAutoScan = false;

  void Function()? onDisconnected;

  void enableSkipMode() {
    skipMode = true;
    reconnectEnabled = false;
  }

  void disableSkipMode() {
    skipMode = false;
    reconnectEnabled = true;
  }

  Future<void> connect(BluetoothDevice d) async {
    if (_isConnecting) {
      throw Exception("A BLE connection is already in progress.");
    }

    _isConnecting = true;

    try {
      await _connSub?.cancel();
      _connSub = null;

      disableSkipMode();

      try {
        await device?.disconnect();
      } catch (_) {}

      try {
        await d.disconnect();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 500));

      device = d;
      dataInChar = null;

      debugPrint("BLE connect start: ${d.remoteId} name=${d.platformName}");

      await d.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 12),
      );

      _connSub = d.connectionState.listen((s) {
        debugPrint("BLE state: $s");

        if (s == BluetoothConnectionState.disconnected) {
          dataInChar = null;
          device = null;

          if (!skipMode) {
            onDisconnected?.call();
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 400));

      List<BluetoothService> services = [];
      try {
        services = await d.discoverServices();
      } catch (e) {
        debugPrint("discoverServices failed (1st try): $e");
        await Future.delayed(const Duration(milliseconds: 500));
        services = await d.discoverServices();
      }

      for (final s in services) {
        debugPrint("Service UUID: ${s.uuid}");
        if (s.uuid == BleUuids.service) {
          for (final c in s.characteristics) {
            debugPrint(
              "Characteristic UUID: ${c.uuid}, "
              "write=${c.properties.write}, "
              "writeWithoutResponse=${c.properties.writeWithoutResponse}",
            );

            if (c.uuid == BleUuids.dataIn) {
              if (c.properties.write || c.properties.writeWithoutResponse) {
                dataInChar = c;
                debugPrint("BLE ready: DataIn characteristic found");
                return;
              }
            }
          }
        }
      }

      await disconnect();
      throw Exception("DataIn characteristic not found. Check UUIDs/services.");
    } catch (e) {
      debugPrint("BLE connect error: $e");
      dataInChar = null;
      device = null;
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    reconnectEnabled = false;

    final d = device;

    dataInChar = null;
    device = null;

    await _connSub?.cancel();
    _connSub = null;

    try {
      await d?.disconnect();
    } catch (_) {}

    // IMPORTANT: let phone BLE stack fully release old session
    await Future.delayed(const Duration(milliseconds: 700));
  }

  Future<void> writePortValue(int port, int value) async {
    final c = dataInChar;
    if (c == null) {
      throw Exception("Not connected / DataIn not ready.");
    }

    final p = port.clamp(0, 255) & 0xFF;
    final v = value.clamp(0, 255) & 0xFF;

    isWriting = true;
    reconnectEnabled = false;

    try {
      final canWriteNoRsp = c.properties.writeWithoutResponse;
      await c.write([p, v], withoutResponse: canWriteNoRsp);
    } catch (e) {
      debugPrint("BLE write error: $e");
      rethrow;
    } finally {
      await Future.delayed(const Duration(milliseconds: 250));
      isWriting = false;
      reconnectEnabled = true;
    }
  }

  Future<void> setVolume(int v0to30) async {
    if (!isReady) return;
    await writePortValue(0, v0to30.clamp(0, 30));
  }

  Future<void> setBass(int v0to30) async {
    if (!isReady) return;
    await writePortValue(1, v0to30.clamp(0, 30));
  }

  Future<void> setMid(int v0to30) async {
    if (!isReady) return;
    await writePortValue(2, v0to30.clamp(0, 30));
  }

  Future<void> setTreble(int v0to30) async {
    if (!isReady) return;
    await writePortValue(3, v0to30.clamp(0, 30));
  }
}