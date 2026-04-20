// lib/ble_uuids.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleUuids {
  static final Guid service =
      Guid("94fa7d4e-136a-43d2-9f08-c8f296530110");

  // MCU "DataIn" writable characteristic (UUID0)
  static final Guid dataIn =
      Guid("df170f02-3641-4594-806d-c113a27ce6cb");
}
