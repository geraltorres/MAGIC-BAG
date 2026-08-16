import '../entities/bag_status.dart';

abstract class BagRepository {
  Stream<BagStatus> get statusStream;
  // Manejo de hardware
  Future<bool> requestRuntimePermissions();
  void startScanningForDevice(String name);
  Future<void> sendRawCommand(String cmd);

  // Gestión de ciclo de vida
  Future<void> disconnect();

  void initAdapterListener() {}

  Future<void> checkAndOpenBluetooth();
}
