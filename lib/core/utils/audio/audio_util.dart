import 'dart:math' as math;
import 'dart:typed_data';

class AudioUtil {
  static double calculateAmplitude(Uint8List bytes) {
    // Convertimos los bytes (Uint8) a una lista de enteros de 16 bits (Int16)
    // El audio PCM de Vosk suele ser de 16 bits.
    final Int16List samples = bytes.buffer.asInt16List();

    if (samples.isEmpty) return 0.0;

    double sumOfSquares = 0.0;
    for (int sample in samples) {
      // Normalizamos el valor (Int16 va de -32768 a 32767)
      double normalized = sample / 32768.0;
      sumOfSquares += normalized * normalized;
    }

    // Calculamos la raíz de la media de los cuadrados (RMS)
    double rms = math.sqrt(sumOfSquares / samples.length);

    // Retornamos un valor suavizado (puedes ajustar el multiplicador según tu micro)
    return rms.clamp(0.0, 1.0);
  }
}
