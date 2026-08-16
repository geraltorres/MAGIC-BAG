import '../constants/arduino_constants.dart';

class CommandParser {
  /// Limpia y traduce cualquier input de texto a un comando de Arduino.
  /// Centralizamos aquí para que sea testeable unitariamente.
  static String parse(String rawInput) {
    if (rawInput.isEmpty) return ArduinoConstants.cmdOff;

    String commandToParse = rawInput;

    if (rawInput.contains("mode=")) {
      try {
        // Usamos la clase Uri de Dart para segmentar la URL de forma limpia
        final uri = Uri.parse(rawInput);
        commandToParse = uri.queryParameters['mode'] ?? rawInput;
      } catch (e) {
        // Si falla el parseo (por el formato de Android), usamos un split simple
        commandToParse = rawInput.split('mode=').last;
      }
    }

    commandToParse = removeAccents(commandToParse);

    // 1. Sanitización estándar (Telecom Grade)
    final clean = commandToParse.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    ); // Elimina emojis, puntos, comas.

    // 2. Diccionario de Intenciones
    // Agrupamos por 'intento' para facilitar el mantenimiento

    if (_hasMatch(clean, ['desconectar'])) {
      return ArduinoConstants.cmdTurnOff;
    }

    if (_hasMatch(clean, ['fijo', 'prender', 'encender', 'luz', 'on'])) {
      return ArduinoConstants.cmdOn;
    }

    if (_hasMatch(clean, [
      'ruta',
      'viaje',
      'moto',
      'parpadeo',
      'pulso',
      'ruda',
    ])) {
      return ArduinoConstants.cmdRoute;
    }

    if (_hasMatch(clean, ['ritmo', 'musica', 'music', 'fiesta', 'ritmico'])) {
      return ArduinoConstants.cmdMusic;
    }

    if (_hasMatch(clean, ['apagar', 'off', 'detener', 'quieto', 'chao'])) {
      return ArduinoConstants.cmdOff;
    }

    return ArduinoConstants.cmdNone; // Fail-safe
  }

  static removeAccents(String input) {
    const withAccents = 'áéíóúüñÁÉÍÓÚÜÑ';
    const withoutAccents = 'aeiouunAEIOUUN';

    for (int i = 0; i < withAccents.length; i++) {
      input = input.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return input;
  }

  static bool _hasMatch(String input, List<String> keywords) {
    return keywords.any((k) => input.contains(k));
  }
}
