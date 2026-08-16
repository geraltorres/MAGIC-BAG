import 'dart:async';
import 'package:flutter/services.dart';
import 'package:magic_bag/core/constants/arduino_constants.dart';
import 'package:magic_bag/core/enums/selection_source.dart';
import 'package:magic_bag/core/errors/failures.dart';
import 'package:magic_bag/domain/entities/bag_status.dart';
import 'package:magic_bag/domain/uses_cases/process_voice_command.dart';
import 'package:magic_bag/providers/bluetooth/repository_provider.dart';
import 'package:magic_bag/providers/microphone/voice_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Este archivo será generado por riverpod_generator
part 'bag_provider.g.dart';

@riverpod
class BagControl extends _$BagControl {
  static const _platform = MethodChannel('com.lonewolf.magicbag/shortcuts');

  @override
  BagStatus build() {
    final repo = ref.watch(bagRepositoryProvider);

    // Al construir el provider, nos aseguramos de que el listener esté activo
    repo.initAdapterListener();
    listenToNative();

    // Escuchamos tanto datos como ERRORES del Stream
    repo.statusStream.listen(
      (newStatus) {
        state = state.copyWith(
          isConnected: newStatus.isConnected,
          isScanning: false,
        );
        updateConnection(state.isConnected);
      },
      onError: (error) {
        if (error is Failure) {
          // Guardamos el error en el estado para que la UI lo pinte
          state = state.copyWith(errorMessage: error.message);
          // Opcional: Limpiar el error después de 3 segundos
          Future.delayed(const Duration(seconds: 3), () {
            state = state.copyWith(errorMessage: null);
          });
        }
      },
    );

    return BagStatus();
  }

  // 1. SOLICITUD DE PERMISOS (Delegado al Repositorio o Service)
  Future<bool> requestPermissions() async {
    final repo = ref.read(bagRepositoryProvider);
    final granted = await repo.requestRuntimePermissions();

    if (granted) {
      // Si hay permisos, iniciamos la búsqueda
      scanAndConnect();
      initVoiceCommands();
    }
    return granted;
  }

  // 2. ESCANEO Y CONEXIÓN (Lógica de Negocio)
  Future<void> scanAndConnect() async {
    // 1. Forzamos el estado de carga INMEDIATAMENTE
    state = state.copyWith(isScanning: true);

    try {
      final repo = ref.read(bagRepositoryProvider);
      // 2. Iniciamos el proceso de hardware
      repo.startScanningForDevice(ArduinoConstants.deviceName);
      // 3. Opcional: Si el escaneo es muy rápido, podemos dejar el loading
      // un mínimo de 800ms para evitar el "parpadeo" visual (UX de primera)
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      state = state.copyWith(isScanning: false);
      print("Error al iniciar escaneo: $e");
    }
  }

  // 4. COMANDOS DE VOZ (Integración con Caso de Uso)
  void initVoiceCommands() {
    final voiceUseCase = ProcessVoiceCommand();

    ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        final command = voiceUseCase.execute(value.first.path);
        sendCommand(command, source: SelectionSource.voice);
        // Actualizamos el estado para que la UI refleje el modo activado por voz
        state = state.copyWith(
          activeMode: command,
          lastSource: SelectionSource.voice,
        );
      }
    }, onError: (err) => print("Error en Intent de Voz: $err"));

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        final command = voiceUseCase.execute(value.first.path);
        sendCommand(command, source: SelectionSource.voice);
        // Actualizamos el estado para que la UI refleje el modo activado por voz
        state = state.copyWith(
          activeMode: command,
          lastSource: SelectionSource.voice,
        );
      }
    });
  }

  Future<void> sendCommand(
    String cmd, {
    SelectionSource source = SelectionSource.manual,
  }) async {
    // 1. Validamos conexión antes de intentar nada
    if (!state.isConnected) {
      state = state.copyWith(errorMessage: "No hay conexión");
      return;
    }

    await ref.read(bagRepositoryProvider).sendRawCommand(cmd);
    state = state.copyWith(activeMode: cmd, lastSource: source);

    print("Comando [$cmd] enviado vía ${source.name.toUpperCase()}");
  }

  Future<void> updateConnection(bool status) async {
    try {
      // Sincronización "Fire and Forget" con el MainActivity.kt
      await _platform.invokeMethod('updateConnectionStatus', status);
    } on PlatformException catch (e) {
      // Como ingeniero, un print en debug no sobra
      print("Error de canal nativo: ${e.message}");
    }
  }

  Future<void> activateModeTravel() async {
    try {
      // 1. Entrar en modo ventana pequeña
      await _platform.invokeMethod('enterPipMode');
    } on PlatformException catch (e) {
      print("Error al entrar en PiP: ${e.message}");
    }
  }

  void listenToNative() {
    _platform.setMethodCallHandler((call) async {
      if (call.method == "onStopFromPip") {
        print("STOP recibido desde el botón nativo del PiP");
        await ref.read(voiceControllerProvider.notifier).stop();
      }
      if (call.method == "onStartFromPip") {
        print("Start recibido desde el botón nativo del PiP");
        await ref.read(voiceControllerProvider.notifier).initVosk();
      }
    });
  }
}
