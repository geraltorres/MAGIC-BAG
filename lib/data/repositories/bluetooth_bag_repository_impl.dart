import 'dart:async';
import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:magic_bag/core/errors/failures.dart';
import 'package:magic_bag/data/mappers/bag_protocol_mapper.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/arduino_constants.dart';
import '../../domain/entities/bag_status.dart';
import '../../domain/repositories/bag_repository.dart';

class BluetoothBagRepositoryImpl implements BagRepository {
  StreamController<BagStatus>? _statusController;

  // 2. Referencias de hardware
  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _writeChar;

  // 3. Suscripciones activas (Cruciales para la limpieza)
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  int _retryCount = 0;
  static const int maxRetries = 3;
  bool _isScanning = false;
  Timer? _retryTimer;

  BagStatus _lastStatus = const BagStatus(isConnected: false);

  @override
  Stream<BagStatus> get statusStream {
    // Inicialización perezosa del controller
    _statusController ??= StreamController<BagStatus>.broadcast();
    return _statusController!.stream;
  }

  @override
  void initAdapterListener() {
    // Cancelamos cualquier suscripción previa para evitar fugas
    _adapterSub?.cancel();

    // Escuchamos los cambios del chip de Bluetooth del celular
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        print("Bluetooth detectado: ON. Iniciando escaneo automático...");
        startScanningForDevice(ArduinoConstants.deviceName);
      } else if (state == BluetoothAdapterState.off) {
        print("Bluetooth detectado: OFF. Notificando a la UI...");
        _emitStatus(const BagStatus(isConnected: false));
      }
    });
  }

  // 1. GESTIÓN DE PERMISOS NATIVOS
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

  // 2. ESCANEO Y AUTO-CONEXIÓN AL JDY-23
  @override
  void startScanningForDevice(String name) async {
    if (_isScanning) return; // Evita solapamiento de escaneos

    _isScanning = true;

    print("Intento de conexión $_retryCount para: $name");

    // Limpieza preventiva
    await disconnect();

    // Escuchamos resultados del escaneo
    _scanSub = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          final target = results.firstWhere(
            (r) => r.device.platformName == name,
            orElse: () => results.last,
          );

          if (target.device.platformName == name) {
            _stopScanAndResetRetry();
            _connectToDevice(target.device);
          }
        }
      },
      onError: (e) {
        _handleScanFailure(name, "Error en stream: $e");
      },
    );

    // Iniciamos escaneo con timeout
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15), // Crucial para Android 12+
      );
      Future.delayed(const Duration(seconds: 11), () {
        if (_isScanning) {
          _handleScanFailure(
            name,
            "Dispositivo no encontrado en el tiempo límite",
          );
        }
      });
    } catch (e) {
      _handleScanFailure(name, "Error al iniciar scan: $e");
    }
  }

  void _handleScanFailure(String name, String reason) {
    print("Fallo en escaneo: $reason");
    _stopScanAndResetRetry(fullReset: false);

    if (_retryCount < maxRetries) {
      _retryCount++;
      // Esperamos un tiempo incremental antes de reintentar (2s, 4s, 8s)
      final delay = Duration(seconds: _retryCount * 2);
      print("Reintentando en ${delay.inSeconds} segundos...");

      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () => startScanningForDevice(name));
    } else {
      _emitError(
        "No se pudo encontrar la maleta tras $maxRetries intentos. Revisa el hardware.",
      );
      _retryCount =
          0; // Reiniciamos para la próxima vez que el usuario pulse el botón
    }
  }

  void _stopScanAndResetRetry({bool fullReset = true}) {
    FlutterBluePlus.stopScan();
    _isScanning = false;
    _scanSub?.cancel();
    if (fullReset) {
      _retryCount = 0;
      _retryTimer?.cancel();
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _targetDevice = device;
    int serviceDiscoveryTries = 0;
    const int maxServiceTries = 2;

    try {
      // 1. Monitor de estado de conexión en tiempo real
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _emitStatus(const BagStatus(isConnected: false));
          print("Dispositivo desconectado físicamente.");
        }
      });

      // 2. Intento de conexión con timeout
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      print(
        "Conexión establecida con ${device.platformName}. Buscando servicios...",
      );

      // 3. Descubrimiento de servicios con reintento interno
      while (serviceDiscoveryTries < maxServiceTries) {
        try {
          List<BluetoothService> services = await device.discoverServices();

          for (var service in services) {
            if (service.uuid.toString() == ArduinoConstants.serviceUuid) {
              for (var char in service.characteristics) {
                if (char.uuid.toString() == ArduinoConstants.charUuid) {
                  _writeChar = char;
                  _writeChar!.onValueReceived.listen((rawBytes) {
                    // AQUÍ USAMOS EL MAPPER DE ENTRADA
                    final frame = BagProtocolMapper.fromBytes(rawBytes);

                    if (frame != null) {
                      _handleHardwareTelemetry(frame);
                    }
                  });
                  _emitStatus(const BagStatus(isConnected: true));
                  print("¡Canal de telemetría listo! UART TX/RX vinculado.");
                  return; // Éxito total
                }
              }
            }
          }
          throw Exception("Servicio JDY-23 no encontrado en el perfil.");
        } catch (e) {
          serviceDiscoveryTries++;
          print(
            "Reintentando descubrimiento de servicios ($serviceDiscoveryTries)...",
          );
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      _emitError("El JDY-23 no expone los servicios esperados.");
    } catch (e) {
      _emitError("Error crítico de conexión: $e");
      await disconnect(); // Limpieza inmediata
    }
  }

  void _handleHardwareTelemetry(BagFrame frame) {
    // Usamos nuestra variable de memoria interna
    final currentStatus = _lastStatus;

    if (frame.id == ArduinoConstants.idAck) {
      print("✅ Confirmación de comando: ${frame.value}");
      // Si necesitas que la UI sepa que hubo un ACK, emite un status con isConnected true
      _emitStatus(const BagStatus(isConnected: true));
    } else if (frame.id == ArduinoConstants.idBattery) {
      print("🔋 Batería: ${frame.value}%");
      // Aquí emitimos el nuevo porcentaje.
      _emitStatus(
        currentStatus.copyWith(
          isConnected: true,
          // Asegúrate de tener este campo en tu entidad domain/entities/bag_status.dart
          batteryLevel: frame.value,
        ),
      );
    }
  }

  // 4. ENVÍO DE DATOS AL ARDUINO (S8050 Trigger)
  @override
  Future<void> sendRawCommand(String cmd) async {
    if (_writeChar == null) {
      _statusController!.addError(
        const BluetoothFailure("No hay dispositivo vinculado"),
      );
      return;
    }

    try {
      // Intentamos escribir con un timeout para no bloquear el Event Loop

      // EL MAPPER HACE LA MAGIA AQUÍ
      final List<int> packet = BagProtocolMapper.toBytes(cmd);

      await _writeChar!
          .write(packet, withoutResponse: true)
          .timeout(const Duration(milliseconds: 500));

      print("🚀 Magic Bag Link -> Enviado: $cmd como $packet");
    } on TimeoutException {
      _statusController!.addError(const HardwareTimeoutFailure());
    } catch (e) {
      _statusController!.addError(BluetoothFailure("Error de transmisión: $e"));
    }
  }

  @override
  Future<void> disconnect() async {
    print("Iniciando desconexión profunda del sistema...");

    await _adapterSub?.cancel(); // Limpieza profunda como pediste
    _adapterSub = null;

    // A. Cancelar suscripciones de eventos de Bluetooth
    await _scanSub?.cancel();
    _scanSub = null;

    await _connectionSub?.cancel();
    _connectionSub = null;

    // B. Desconexión física del JDY-23
    if (_targetDevice != null) {
      await _targetDevice!.disconnect();
      _targetDevice = null;
    }

    // C. Limpiar referencias de características (S8050 Trigger)
    _writeChar = null;

    // D. Notificar a la UI el estado final antes de cerrar
    if (_statusController != null && !_statusController!.isClosed) {
      _statusController!.add(
        const BagStatus(isConnected: false, activeMode: "0"),
      );

      // E. IMPORTANTE: No cerramos el controller del Singleton
      // a menos que queramos invalidar toda la instancia de GetIt.
      // Solo limpiamos su buffer interno si es necesario.
    }
  }

  // Helper para emitir estados de forma segura
  void _emitStatus(BagStatus status) {
    _lastStatus = status;
    if (_statusController != null && !_statusController!.isClosed) {
      _statusController!.add(status);
    }
  }

  void _emitError(String msg) {
    print(msg);
    _statusController!.add(const BagStatus(isConnected: false));
  }

  @override
  Future<void> checkAndOpenBluetooth() async {
    // 1. Verificamos el estado actual del adaptador
    final adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState == BluetoothAdapterState.off) {
      print("Bluetooth apagado. Disparando Intent de configuración...");

      // 2. Definimos el Intent para la pantalla de ajustes de Bluetooth
      const intent = AndroidIntent(
        action: 'android.settings.BLUETOOTH_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );

      try {
        await intent.launch();
      } catch (e) {
        // Si falla (raro en Android), intentamos con los ajustes generales
        const generalSettings = AndroidIntent(
          action: 'android.settings.SETTINGS',
        );
        await generalSettings.launch();
      }
    }
  }
}
