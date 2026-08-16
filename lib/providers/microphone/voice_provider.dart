import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_bag/core/constants/arduino_constants.dart';
import 'package:magic_bag/core/utils/audio/audio_util.dart';
import 'package:magic_bag/core/utils/command_parser.dart';
import 'package:magic_bag/domain/entities/audio/voice_state.dart';
import 'package:magic_bag/providers/bluetooth/repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:record/record.dart';
import 'package:flutter/services.dart';
import 'package:vosk_flutter_service/vosk_flutter.dart';

part 'voice_provider.g.dart';

@Riverpod(keepAlive: true)
class VoiceController extends _$VoiceController {
  static const _platform = MethodChannel('com.lonewolf.magicbag/shortcuts');

  final _audioRecorder = AudioRecorder();
  VoskFlutterPlugin? _vosk;
  Model? _model;
  Recognizer? _recognizer;
  StreamSubscription<Uint8List>? _audioSubscription;

  Timer? _timeoutTimer;
  static const int _timeoutDuration = 7;

  void toggleMic() async {
    if (state.isListening) {
      stop();
    } else {
      initVosk();
    }
  }

  @override
  VoiceState build() {
    _vosk = VoskFlutterPlugin.instance();
    return VoiceState(
      isListening: false,
      lastCommand: "Modo Viaje OFF",
    ); // isListening
  }

  Future<void> initVosk() async {
    if (state.isListening) return;

    _timeoutTimer?.cancel();

    // Cambio: De state = true a ->
    state = state.copyWith(isListening: true, lastCommand: "Escuchando...");

    try {
      // 1. Activar Micro del Casco (SCO)
      await _platform.invokeMethod('startBluetoothMic');

      _timeoutTimer = Timer(Duration(seconds: _timeoutDuration), () {
        if (state.isListening) {
          stop();
        }
      });

      // 1. Extraer el modelo del APK a la carpeta local del celular
      // Esto es lo que pone el icono en VERDE si funciona
      final modelPath = await ModelLoader().loadFromAssets(
        'assets/models/vosk-model-small-es-0.42.zip',
      );

      print("Modelo listo en: $modelPath");
      // 2. Cargar Modelo
      _model ??= await _vosk!.createModel(modelPath);

      // 3. Crear el Recognizer (16000Hz para Bluetooth SCO)
      _recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );

      _startAudioStream();
      print("¡Cerebro cargado con éxito en $modelPath!");
    } catch (e) {
      state = state.copyWith(isListening: false, lastCommand: "Error Mic");
      print("Error en initVosk: $e");
    }
  }

  Future<void> _startAudioStream() async {
    // Configuración para que Vosk entienda el audio PCM
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );

    // Iniciamos el stream del micrófono
    final stream = await _audioRecorder.startStream(config);

    _audioSubscription = stream.listen((Uint8List bytes) async {
      // 1. AHORA DEBES ACCEDER A .isListening
      if (!state.isListening) return;

      final double amplitude = AudioUtil.calculateAmplitude(bytes);

      // UMBRAL DE CORTE (Threshold)
      // 0.05 - 0.1 suele ser un buen rango para filtrar ruido de fondo.
      // Si vas a mucha velocidad, súbelo a 0.15.
      if (amplitude < 0.08) {
        return; // "Dormimos" a Vosk para ahorrar batería
      }

      // ESTE ES EL MÉTODO DE TU IMAGEN
      // Le inyectamos los bytes al motor de Vosk
      final resultAvailable = await _recognizer?.acceptWaveformBytes(bytes);

      // Si Vosk detectó el final de una frase (silencio corto)
      if (resultAvailable == true) {
        final jsonString = await _recognizer?.getResult();
        if (jsonString != null) {
          _processText(jsonString);
        }
      }
    });
  }

  void _processText(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final String text = data['text'] ?? "";

    if (text.isNotEmpty && text.length > 3) {
      final String comandoArduino = CommandParser.parse(text);
      state = state.copyWith(lastCommand: "COMANDO: $comandoArduino");

      if (comandoArduino != "IGNORE") {
        _sendComandtoBag(comandoArduino);
      }
    }
  }

  void _sendComandtoBag(String comando) {
    print("VOZ -> ARDUINO: $comando");

    try {
      // 1. Obtenemos la referencia al repositorio de la maleta
      // Nota: Asegúrate de que el nombre del provider coincida con el tuyo
      final repository = ref.read(bagRepositoryProvider);

      // 2. Ejecutamos el envío asíncrono
      // No usamos 'await' aquí para no bloquear el flujo de reconocimiento de voz
      repository.sendRawCommand(comando).catchError((e) {
        print("Error enviando comando desde Voz: $e");
      });

      if (comando == ArduinoConstants.cmdTurnOff) {
        _turnOff();
      }

      // 3. (Opcional) Limpiamos el texto después de 3 segundos
      Future.delayed(Duration(seconds: 3), () {
        if (state.isListening) {
          state = state.copyWith(lastCommand: "Escuchando...");
        }
      });
    } catch (e) {
      print("No se pudo acceder al repositorio de la maleta: $e");
    }
  }

  Future<void> _turnOff() async {
    print("Iniciando desconexión total de la Magic Bag...");

    // A. Actualizamos el estado del PiP inmediatamente
    state = state.copyWith(isListening: false, lastCommand: "Desconectando...");

    // B. Detenemos el reconocimiento de voz (Vosk y Mic)
    await stop(); // Tu método que ya cancela la subscripción

    // C. Ordenamos al repositorio cerrar el Bluetooth
    // Asumiendo que tu repository_impl tiene un método de desconexión
    await ref.read(bagRepositoryProvider).disconnect();

    // D. Opcional: Cerrar el modo PiP nativo desde Flutter
    //_platform.invokeMethod('closePip');

    state = state.copyWith(lastCommand: "Sistema OFF");
  }

  Future<void> stop() async {
    _timeoutTimer?.cancel();
    state = state.copyWith(isListening: false, lastCommand: "Modo Viaje OFF");
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder.stop();
    await _recognizer?.dispose();
    await _platform.invokeMethod('stopBluetoothMic');
  }
}
