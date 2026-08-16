import 'package:magic_bag/core/constants/arduino_constants.dart';

class BagFrame {
  final int id;
  final int value;
  final List<int> rawBytes;

  BagFrame(this.id, this.value, this.rawBytes);
}

class BagProtocolMapper {
  static const int _header = 0xA5;

  /// MAPPER DE SALIDA: De Constante String a Paquete de Bytes
  static List<int> toBytes(String command) {
    int id = ArduinoConstants.idMode; // Por defecto es modo
    int value = 0;

    // Mapeamos tus constantes actuales a valores numéricos
    switch (command) {
      case ArduinoConstants.cmdOn:
        value = 0x01;
        break;
      case ArduinoConstants.cmdOff:
        value = 0x00;
        break;
      case ArduinoConstants.cmdRoute:
        value = 0x03;
        break;
      case ArduinoConstants.cmdMusic:
        value = 0x4D;
        break; // 'M'
      case ArduinoConstants.cmdTurnOff:
        id = 0x0F; // Un ID especial para apagado total
        value = 0x00;
        break;
      default:
        value = 0x00;
    }

    final int checksum = (id + value) & 0xFF;
    return [_header, id, value, checksum];
  }

  /// MAPPER DE ENTRADA: De Bytes a Objeto legible (Telemetría)
  static BagFrame? fromBytes(List<int> data) {
    if (data.length < 4) return null;

    for (int i = 0; i < data.length - 3; i++) {
      if (data[i] == _header) {
        int id = data[i + 1];
        int val = data[i + 2];
        int check = data[i + 3];

        if (((id + val) & 0xFF) == check) {
          return BagFrame(id, val, data.sublist(i, i + 4));
        }
      }
    }
    return null;
  }
}
