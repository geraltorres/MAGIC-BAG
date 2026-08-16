import 'package:magic_bag/core/enums/selection_source.dart';

class BagStatus {
  final bool isConnected;
  final String activeMode;
  final bool isScanning;
  final String? deviceId;
  final String? errorMessage;
  final SelectionSource? lastSource;
  final int? batteryLevel;
  final bool isWaitingAck;

  const BagStatus({
    this.isConnected = false,
    this.activeMode = "0",
    this.isScanning = false,
    this.deviceId,
    this.errorMessage,
    this.lastSource,
    this.batteryLevel,
    this.isWaitingAck = false,
  });

  // Copia inmutable para el manejo de estados
  BagStatus copyWith({
    bool? isConnected,
    String? activeMode,
    String? deviceId,
    String? errorMessage,
    bool? isScanning,
    SelectionSource? lastSource,
    int? batteryLevel,
    bool? isWaitingAck,
  }) {
    return BagStatus(
      isConnected: isConnected ?? this.isConnected,
      activeMode: activeMode ?? this.activeMode,
      deviceId: deviceId ?? this.deviceId,
      errorMessage: errorMessage,
      isScanning: isScanning ?? this.isScanning,
      lastSource: lastSource ?? this.lastSource,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isWaitingAck: isWaitingAck ?? this.isWaitingAck,
    );
  }

  @override
  List<Object?> get props => [
    isConnected,
    activeMode,
    batteryLevel,
    isWaitingAck,
  ];
}
