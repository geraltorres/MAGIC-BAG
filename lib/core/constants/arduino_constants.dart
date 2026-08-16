class ArduinoConstants {
  // UUIDs estándar para módulos JDY-23 / HM-10
  static const String serviceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String charUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";

  // Protocolo de comunicación (Bytes seriales)
  static const int idMode = 0x01;
  static const String cmdOff = "0";
  static const String cmdTurnOff = "TURNOFF";
  static const String cmdOn = "1";
  static const String cmdRoute = "3";
  static const String cmdMusic = "M";
  static const String cmdNone = "IGNORE";

  // Nombres de dispositivos conocidos
  static const String deviceName = "JDY-23";

  // Protocolo Binario (Nuevas)
  static const int header = 0xA5;
  static const int idBattery = 0x02;
  static const int idAck = 0xFF;
}
