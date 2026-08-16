import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_bag/providers/microphone/voice_provider.dart';

class MiniBagWidget extends ConsumerWidget {
  const MiniBagWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el estado del micrófono
    final voiceState = ref.watch(voiceControllerProvider);

    // Lógica de colores:
    // Si no hay conexión con la maleta o el micro falló -> Rojo
    // Si todo está ok -> Verde
    final statusColor = (voiceState.isListening)
        ? Colors.greenAccent
        : Colors.redAccent;

    return Center(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          boxShadow: [
            if (voiceState.isListening)
              BoxShadow(color: Colors.green, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              voiceState.isListening ? Icons.mic : Icons.mic_off,
              color: Colors.white,
              size: 30,
            ),
            Text(voiceState.lastCommand, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
