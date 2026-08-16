import 'package:magic_bag/core/constants/arduino_constants.dart';
import 'package:magic_bag/domain/entities/bag_status.dart';
import 'package:magic_bag/domain/repositories/bag_repository.dart';

import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

class MockBluetoothRepository implements BagRepository {
  final _statusController = StreamController<BagStatus>.broadcast();

  @override
  Stream<BagStatus> get statusStream => _statusController.stream;

  @override
  void startScanningForDevice(String name) async {
    // Simulamos que tarda 2 segundos en "encontrar" la maleta
    await Future.delayed(const Duration(seconds: 2));
    _statusController.add(
      BagStatus(
        isConnected: true,
        isScanning: false,
        activeMode: ArduinoConstants.cmdOn,
      ),
    ); // ¡Conectado! (Simulado)
  }

  @override
  Future<void> disconnect() async {
    _statusController.add(
      BagStatus(isConnected: false, activeMode: ArduinoConstants.cmdOff),
    );
  }

  @override
  Future<void> checkAndOpenBluetooth() async {}

  @override
  void initAdapterListener() {}

  @override
  Future<bool> requestRuntimePermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.audio,
      Permission.microphone,
    ].request();

    return statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.microphone]!.isGranted;
  }

  @override
  Future<void> sendRawCommand(String cmd) async {
    // Solo imprimimos en consola para verificar que el Core envió el byte correcto
    print("MOCK BTH: Enviando byte '$cmd' al transistor S8050...");
    _statusController.add(
      BagStatus(isConnected: true, activeMode: ArduinoConstants.cmdRoute),
    ); // ¡Conectado! (Simulado)
  }
}
