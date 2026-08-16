abstract class Failure {
  final String message;
  const Failure(this.message);
}

class BluetoothFailure extends Failure {
  const BluetoothFailure(String message) : super(message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(String message) : super(message);
}

class HardwareTimeoutFailure extends Failure {
  const HardwareTimeoutFailure()
    : super("El JDY-23 no responde. Revisa la alimentación.");
}
