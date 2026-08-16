class VoiceState {
  final bool isListening;
  final String lastCommand;

  VoiceState({required this.isListening, this.lastCommand = "Esperando..."});

  // Método helper para copiar el estado fácilmente
  VoiceState copyWith({bool? isListening, String? lastCommand}) {
    return VoiceState(
      isListening: isListening ?? this.isListening,
      lastCommand: lastCommand ?? this.lastCommand,
    );
  }
}
