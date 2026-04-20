import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'account_button.dart';
import 'connection_page.dart';
import 'piano_page.dart';
import 'transitions.dart';
import 'ble_connection.dart';
import 'app_locale.dart';
import 'dynamic_gradient_slider.dart';
import 'disconnection_page.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  static const String deviceName = "TIAmpEsp";
  static const String serviceUid =
      "94fa7d4e-136a-43d2-9f08-c8f296530110";

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  double volume = 15;
  double bass = 0;
  double mid = 0;
  double treble = 0;

  String selectedMode = "Custom";

  Map<String, Map<String, double>> customPresets = {};

  StreamSubscription<BluetoothConnectionState>? _bleConnSub;
  bool _handlingDisconnect = false;

  Timer? _volumeWriteTimer;
  Timer? _bassWriteTimer;
  Timer? _midWriteTimer;
  Timer? _trebleWriteTimer;

  String backgroundMode = 'white'; // white, black, image
  String? backgroundImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  final Map<String, Map<String, double>> defaultPresets = const {
    "Rock": {"bass": 20, "mid": 14, "treble": 22},
    "Jazz": {"bass": 18, "mid": 18, "treble": 18},
    "Classical": {"bass": 16, "mid": 16, "treble": 24},
    "Pop": {"bass": 19, "mid": 20, "treble": 16},
    "Custom": {"bass": 0, "mid": 0, "treble": 0},
  };

  late final String _userPrefix;

  @override
  void initState() {
    super.initState();

    _handlingDisconnect = false;
    _startBleDisconnectWatcher();

    final user = FirebaseAuth.instance.currentUser;
    _userPrefix = user?.uid ?? 'guest';

    _loadAll();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final msg = BleController.instance.skipMode
          ? t(
              'Entered control page without MCU connection',
              '未连接 MCU，已进入控制页面',
              'Se abrió la página de control sin conexión al MCU',
            )
          : 'Connected to ${ControlScreen.serviceUid}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  void _startBleDisconnectWatcher() {
    final stream = BleController.instance.connectionStateStream;
    if (stream == null) return;

    _bleConnSub?.cancel();
    _bleConnSub = stream.listen((state) async {
      if (!mounted) return;

      if (BleController.instance.skipMode) return;

      if (state == BluetoothConnectionState.disconnected) {
        if (BleController.instance.isWriting) return;

        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;

        if (_handlingDisconnect) return;
        await _handleMcuDisconnected();
      }
    });
  }

  Future<void> _handleMcuDisconnected() async {
    if (_handlingDisconnect) return;
    if (BleController.instance.skipMode) return;

    _handlingDisconnect = true;

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'MCU disconnected. Returning to connection page…',
            'MCU 已断开连接，正在返回连接页面…',
            'MCU desconectado. Volviendo a la página de conexión…',
          ),
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      FadePageRoute(child: const ConnectionPage()),
      (route) => false,
    );
  }

  void _scheduleVolumeWrite() {
    _volumeWriteTimer?.cancel();
    _volumeWriteTimer = Timer(const Duration(milliseconds: 80), () {
      _writeBlePortValue(0, _encodeVolume(volume));
    });
  }

  void _scheduleBassWrite() {
    _bassWriteTimer?.cancel();
    _bassWriteTimer = Timer(const Duration(milliseconds: 80), () {
      _writeBlePortValue(1, _encodeEq(bass));
    });
  }

  void _scheduleMidWrite() {
    _midWriteTimer?.cancel();
    _midWriteTimer = Timer(const Duration(milliseconds: 80), () {
      _writeBlePortValue(2, _encodeEq(mid));
    });
  }

  void _scheduleTrebleWrite() {
    _trebleWriteTimer?.cancel();
    _trebleWriteTimer = Timer(const Duration(milliseconds: 80), () {
      _writeBlePortValue(3, _encodeEq(treble));
    });
  }

  String _prefKey(String base) => '${_userPrefix}_$base';
  String _presetKey(String name) => 'preset_${_userPrefix}_$name';

  Future<void> _loadAll() async {
    await _loadLastSessionValues();
    await _loadCustomPresets();
    await _loadBackgroundSettings();
  }

  void _giveFeedback(String message, {bool vibrate = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 700),
      ),
    );
    if (vibrate) HapticFeedback.lightImpact();
  }

  Future<void> _loadLastSessionValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      volume = prefs.getDouble(_prefKey('volume')) ?? volume;
      bass = prefs.getDouble(_prefKey('bass')) ?? 0;
      mid = prefs.getDouble(_prefKey('mid')) ?? 0;
      treble = prefs.getDouble(_prefKey('treble')) ?? 0;
      selectedMode = prefs.getString(_prefKey('mode')) ?? "Custom";
    });
  }

  Future<void> _saveLastSessionValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKey('volume'), volume);
    await prefs.setDouble(_prefKey('bass'), bass);
    await prefs.setDouble(_prefKey('mid'), mid);
    await prefs.setDouble(_prefKey('treble'), treble);
    await prefs.setString(_prefKey('mode'), selectedMode);
  }

  Future<void> _loadCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final base = 'preset_${_userPrefix}_';

    final keys = prefs.getKeys().where((k) => k.startsWith(base));
    final loaded = <String, Map<String, double>>{};
    for (final key in keys) {
      final name = key.substring(base.length);
      final data = prefs.getStringList(key);
      if (data != null) {
        if (data.length == 4) {
          loaded[name] = {
            "volume": double.tryParse(data[0]) ?? 15,
            "bass": double.tryParse(data[1]) ?? 0,
            "mid": double.tryParse(data[2]) ?? 0,
            "treble": double.tryParse(data[3]) ?? 0,
          };
        } else if (data.length == 3) {
          loaded[name] = {
            "volume": 15,
            "bass": double.tryParse(data[0]) ?? 0,
            "mid": double.tryParse(data[1]) ?? 0,
            "treble": double.tryParse(data[2]) ?? 0,
          };
        }
      }
    }
    setState(() => customPresets = loaded);
  }

  Future<void> _savePreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_presetKey(name), [
      volume.toString(),
      bass.toString(),
      mid.toString(),
      treble.toString(),
    ]);
    await _loadCustomPresets();
  }

  Future<void> _loadBackgroundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      backgroundMode = prefs.getString(_prefKey('background_mode')) ?? 'white';
      backgroundImagePath = prefs.getString(_prefKey('background_image_path'));
    });
  }

  Future<void> _saveBackgroundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey('background_mode'), backgroundMode);

    if (backgroundImagePath != null && backgroundImagePath!.isNotEmpty) {
      await prefs.setString(
        _prefKey('background_image_path'),
        backgroundImagePath!,
      );
    } else {
      await prefs.remove(_prefKey('background_image_path'));
    }
  }

  Future<void> _setBackgroundMode(String mode) async {
    setState(() {
      backgroundMode = mode;
    });
    await _saveBackgroundSettings();
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() {
        backgroundMode = 'image';
        backgroundImagePath = file.path;
      });

      await _saveBackgroundSettings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Background image updated',
              '背景图片已更新',
              'Imagen de fondo actualizada',
            ),
          ),
          duration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      debugPrint('pick background image error: $e');
    }
  }

  Widget _buildPageBackground({required Widget child}) {
    if (backgroundMode == 'image' &&
        backgroundImagePath != null &&
        backgroundImagePath!.isNotEmpty &&
        File(backgroundImagePath!).existsSync()) {
      return Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              File(backgroundImagePath!),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.30),
            ),
          ),
          child,
        ],
      );
    }

    final bgColor = backgroundMode == 'black' ? Colors.black : Colors.white;

    return Container(
      color: bgColor,
      child: child,
    );
  }

  Future<void> _saveCustomFlow() async {
    final controller = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Save Custom Preset', '保存自定义预设', 'Guardar preset')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: t('Preset name', '预设名称', 'Nombre del preset'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(t('Cancel', '取消', 'Cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(t('Save', '保存', 'Guardar')),
          ),
        ],
      ),
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    if (customPresets.containsKey(trimmed)) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('Overwrite preset', '覆盖预设', 'Sobrescribir preset')),
          content: Text(
            t(
              'Overwrite "$trimmed"?',
              '覆盖 "$trimmed" 吗？',
              '¿Sobrescribir "$trimmed"?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('No', '否', 'No')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('Yes', '是', 'Sí')),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
    }

    await _savePreset(trimmed);
    setState(() => selectedMode = trimmed);
    await _saveLastSessionValues();
    _giveFeedback(
      t(
        'Preset "$trimmed" saved!',
        '预设 "$trimmed" 已保存！',
        '¡Preset "$trimmed" guardado!',
      ),
    );
  }

  int _encodeVolume(double v) {
    int iv = v.round();
    if (iv < 0) iv = 0;
    if (iv > 30) iv = 30;
    return iv;
  }

  int _encodeEq(double v) {
    int iv = v.round();
    if (iv < 0) iv = 0;
    if (iv > 30) iv = 30;
    return iv;
  }

  Future<void> _writeBlePortValue(int port, int value) async {
    try {
      await BleController.instance.writePortValue(port, value);
      debugPrint('[BLE WRITE] port=$port value=$value');
    } catch (e) {
      debugPrint('[BLE WRITE ERROR] $e');

      if (!mounted) return;
      if (BleController.instance.skipMode) return;
      if (_handlingDisconnect) return;

      await _handleMcuDisconnected();
    }
  }

  String localizedModeName(String mode) {
    switch (mode) {
      case 'Rock':
        return t('Rock', '摇滚', 'Rock');
      case 'Jazz':
        return t('Jazz', '爵士', 'Jazz');
      case 'Classical':
        return t('Classical', '古典', 'Clásica');
      case 'Pop':
        return t('Pop', '流行', 'Pop');
      case 'Custom':
        return t('Custom', '自定义', 'Personalizado');
      default:
        return mode;
    }
  }

  void _applyMode(String mode) {
    Map<String, double>? source;
    if (defaultPresets.containsKey(mode)) {
      source = defaultPresets[mode]!;
    } else if (customPresets.containsKey(mode)) {
      source = customPresets[mode]!;
    }

    setState(() {
      selectedMode = mode;
      if (source != null && mode != "Custom") {
        volume = source["volume"] ?? volume;
        bass = source["bass"] ?? 0;
        mid = source["mid"] ?? 0;
        treble = source["treble"] ?? 0;
      }
    });

    _saveLastSessionValues();
    _giveFeedback(
      t('Switched to $mode mode', '已切换到 $mode 模式', 'Cambiado al modo $mode'),
    );

    _writeBlePortValue(0, _encodeVolume(volume));
    _writeBlePortValue(1, _encodeEq(bass));
    _writeBlePortValue(2, _encodeEq(mid));
    _writeBlePortValue(3, _encodeEq(treble));
  }

  void _reset() {
    setState(() {
      volume = 15;
      bass = 15;
      mid = 15;
      treble = 15;
      selectedMode = "Custom";
    });
    _saveLastSessionValues();
    _giveFeedback(
      t('Settings reset', '设置已重置', 'Ajustes restablecidos'),
      vibrate: true,
    );

    _writeBlePortValue(0, _encodeVolume(volume));
    _writeBlePortValue(1, _encodeEq(bass));
    _writeBlePortValue(2, _encodeEq(mid));
    _writeBlePortValue(3, _encodeEq(treble));
  }

  Future<void> _disconnect() async {
    _handlingDisconnect = true;

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      FadePageRoute(child: const DisconnectingPage()),
      (route) => false,
    );
  }

  Future<void> _openManagePresets() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final double bodyWidth = mq.size.width.clamp(320.0, 480.0);
        final double bodyHeight = mq.size.height.clamp(300.0, 480.0);

        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: Text(t('Manage Presets', '管理预设', 'Administrar presets')),
          content: SizedBox(
            width: bodyWidth,
            height: bodyHeight,
            child: _ManagePresetsDialog(
              userPrefix: _userPrefix,
              onAnyChange: () async {
                await _loadCustomPresets();
                if (!customPresets.containsKey(selectedMode) &&
                    !defaultPresets.containsKey(selectedMode)) {
                  setState(() => selectedMode = "Custom");
                  await _saveLastSessionValues();
                } else {
                  setState(() {});
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('Close', '关闭', 'Cerrar')),
            ),
          ],
        );
      },
    );
  }

  List<Color> _sliderGradientColors(String label) {
    if (label == t('Volume', '音量', 'Volumen')) {
      return const [
        Color(0xFF00C6FF),
        Color(0xFF0072FF),
        Color(0xFF7B61FF),
      ];
    } else if (label == t('Bass', '低音', 'Bajos')) {
      return const [
        Color(0xFF11998E),
        Color(0xFF38EF7D),
        Color(0xFFB6FF6C),
      ];
    } else if (label == t('Mid', '中音', 'Medios')) {
      return const [
        Color(0xFFFF8C42),
        Color(0xFFFFC94A),
        Color(0xFFFFF07A),
      ];
    } else {
      return const [
        Color(0xFFFF512F),
        Color(0xFFDD2476),
        Color(0xFF8E2DE2),
      ];
    }
  }

  String _sliderValueText(String label, double value) {
    final i = value.round();
    if (label == t('Volume', '音量', 'Volumen')) return '$i%';
    return '$i';
  }

  @override
  void dispose() {
    _bleConnSub?.cancel();
    _volumeWriteTimer?.cancel();
    _bassWriteTimer?.cancel();
    _midWriteTimer?.cancel();
    _trebleWriteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = !BleController.instance.skipMode &&
        BleController.instance.device != null &&
        BleController.instance.dataInChar != null;

    final allModes = <String>[
      ...defaultPresets.keys,
      ...customPresets.keys,
    ];

    final volumeLabel = t('Volume', '音量', 'Volumen');
    final bassLabel = t('Bass', '低音', 'Bajos');
    final midLabel = t('Mid', '中音', 'Medios');
    final trebleLabel = t('Treble', '高音', 'Agudos');

    final bool isDarkBg =
        backgroundMode == 'black' || backgroundMode == 'image';
    final pageTextColor = isDarkBg ? Colors.white : Colors.black;
    final subtleTextColor = isDarkBg
        ? Colors.white.withOpacity(0.72)
        : Colors.black.withOpacity(0.72);

    final cardColor = backgroundMode == 'image'
        ? const Color(0xFF171A1F).withOpacity(0.78)
        : isDarkBg
            ? const Color(0xFF171A1F).withOpacity(0.92)
            : Colors.white.withOpacity(0.92);

    final borderColor = backgroundMode == 'image'
        ? Colors.white.withOpacity(0.12)
        : isDarkBg
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.08);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(t('Amp Controller', '功放控制器', 'Controlador de amplificador')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnect,
        ),
        actions: const [
          AccountButton(),
        ],
      ),
      backgroundColor: Colors.transparent,
      body: _buildPageBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (connected)
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.memory, color: pageTextColor),
                      title: Text(
                        ControlScreen.deviceName,
                        style: TextStyle(color: pageTextColor),
                      ),
                      subtitle: Text(
                        'ID: ${ControlScreen.serviceUid}',
                        style: TextStyle(color: subtleTextColor),
                      ),
                      trailing: ElevatedButton(
                        onPressed: _disconnect,
                        child: Text(t('Disconnect', '断开连接', 'Desconectar')),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Background', '背景', 'Fondo'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: pageTextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: () => _setBackgroundMode('white'),
                              child: Text(t('White', '白色', 'Blanco')),
                            ),
                            ElevatedButton(
                              onPressed: () => _setBackgroundMode('black'),
                              child: Text(t('Black', '黑色', 'Negro')),
                            ),
                            ElevatedButton(
                              onPressed: _pickBackgroundImage,
                              child: Text(
                                t('Choose Photo', '选择图片', 'Elegir foto'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t('Mode: ', '模式：', 'Modo: '),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: pageTextColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          dropdownColor: cardColor,
                          value: allModes.contains(selectedMode)
                              ? selectedMode
                              : "Custom",
                          style: TextStyle(color: pageTextColor),
                          items: allModes
                              .map(
                                (mode) => DropdownMenuItem<String>(
                                  value: mode,
                                  child: Text(localizedModeName(mode)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => v == null ? null : _applyMode(v),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _openManagePresets,
                      icon: const Icon(Icons.tune),
                      label: Text(
                        t('Manage Presets', '管理预设', 'Administrar presets'),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DynamicGradientSlider(
                  label: volumeLabel,
                  icon: Icons.volume_up,
                  iconColor: Colors.blue,
                  cardColor: cardColor,
                  textColor: pageTextColor,
                  borderColor: borderColor,

                  value: (volume / 30) * 100,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  valueText: '${((volume / 30) * 100).round()}%',

                  activeColors: _sliderGradientColors(volumeLabel),

                  onChanged: (v) {
                    setState(() {
                      volume = ((v / 100) * 30).roundToDouble();
                    });
                    _saveLastSessionValues();
                    _scheduleVolumeWrite();
                  },

                  onChangeEnd: (_) {
                    _writeBlePortValue(0, _encodeVolume(volume));
                  },
                ),
                DynamicGradientSlider(
                  label: bassLabel,
                  icon: Icons.music_note,
                  iconColor: const Color(0xFF38EF7D),
                  cardColor: cardColor,
                  textColor: pageTextColor,
                  borderColor: borderColor,
                  value: bass,
                  min: 0,
                  max: 30,
                  divisions: 30,
                  valueText: _sliderValueText(bassLabel, bass),
                  activeColors: _sliderGradientColors(bassLabel),
                  onChanged: (v) {
                    setState(() {
                      bass = v;
                      selectedMode = "Custom";
                    });
                    _saveLastSessionValues();
                    _scheduleBassWrite();
                  },
                  onChangeEnd: (_) {
                    _writeBlePortValue(1, _encodeEq(bass));
                  },
                ),
                DynamicGradientSlider(
                  label: midLabel,
                  icon: Icons.equalizer,
                  iconColor: Colors.orange,
                  cardColor: cardColor,
                  textColor: pageTextColor,
                  borderColor: borderColor,
                  value: mid,
                  min: 0,
                  max: 30,
                  divisions: 30,
                  valueText: _sliderValueText(midLabel, mid),
                  activeColors: _sliderGradientColors(midLabel),
                  onChanged: (v) {
                    setState(() {
                      mid = v;
                      selectedMode = "Custom";
                    });
                    _saveLastSessionValues();
                    _scheduleMidWrite();
                  },
                  onChangeEnd: (_) {
                    _writeBlePortValue(2, _encodeEq(mid));
                  },
                ),
                DynamicGradientSlider(
                  label: trebleLabel,
                  icon: Icons.graphic_eq,
                  iconColor: Colors.pink,
                  cardColor: cardColor,
                  textColor: pageTextColor,
                  borderColor: borderColor,
                  value: treble,
                  min: 0,
                  max: 30,
                  divisions: 30,
                  valueText: _sliderValueText(trebleLabel, treble),
                  activeColors: _sliderGradientColors(trebleLabel),
                  onChanged: (v) {
                    setState(() {
                      treble = v;
                      selectedMode = "Custom";
                    });
                    _saveLastSessionValues();
                    _scheduleTrebleWrite();
                  },
                  onChangeEnd: (_) {
                    _writeBlePortValue(3, _encodeEq(treble));
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh),
                        label: Text(t('Reset', '重置', 'Restablecer')),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _saveCustomFlow,
                        icon: const Icon(Icons.save),
                        label: Text(
                          t('Save Custom', '保存自定义', 'Guardar personalizado'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      t('Instrument', '乐器', 'Instrumento'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: pageTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t('Opening Piano…', '正在打开钢琴…', 'Abriendo piano…'),
                            ),
                            duration: const Duration(milliseconds: 600),
                          ),
                        );
                        Navigator.of(context).push(
                          SlideRightRoute(child: const PianoPage2Octaves()),
                        );
                      },
                      icon: const Icon(Icons.piano),
                      label: Text(t('Piano', '钢琴', 'Piano')),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagePresetsDialog extends StatefulWidget {
  const _ManagePresetsDialog({
    required this.onAnyChange,
    required this.userPrefix,
  });

  final Future<void> Function() onAnyChange;
  final String userPrefix;

  @override
  State<_ManagePresetsDialog> createState() => _ManagePresetsDialogState();
}

class _ManagePresetsDialogState extends State<_ManagePresetsDialog> {
  List<String> _names = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _presetKey(String name) => 'preset_${widget.userPrefix}_$name';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final base = 'preset_${widget.userPrefix}_';
    final keys = prefs.getKeys().where((k) => k.startsWith(base));
    final names = keys.map((k) => k.substring(base.length)).toList()..sort();
    if (mounted) setState(() => _names = names);
  }

  Future<void> _delete(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Delete preset', '删除预设', 'Eliminar preset')),
        content: Text(
          t('Delete "$name"?', '删除 "$name" 吗？', '¿Eliminar "$name"?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancel', '取消', 'Cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Delete', '删除', 'Eliminar')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_presetKey(name));
    await _load();
    await widget.onAnyChange();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('Deleted "$name"', '已删除 "$name"', 'Se eliminó "$name"'),
        ),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _names
        : _names
            .where((n) => n.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: t('Search presets', '搜索预设', 'Buscar presets'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (s) => setState(() => _query = s),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          t(
                            'No custom presets found.',
                            '未找到自定义预设。',
                            'No se encontraron presets personalizados.',
                          ),
                        ),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final name = filtered[index];
                          return ListTile(
                            title: Text(name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () => _delete(name),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}