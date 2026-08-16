import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_bag/presentation/widgets/battery_indicator_widget.dart';
import 'package:magic_bag/providers/bag_control/bag_provider.dart';
import 'package:magic_bag/providers/microphone/voice_provider.dart';

class StatusPanel extends ConsumerWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(bagControlProvider);
    final voice = ref.watch(voiceControllerProvider);
    final colors = Theme.of(context).colorScheme;

    // Detectamos la orientación actual
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // El color del fondo del botón
    final backgroundColor = colors.surfaceContainerHighest;

    return isLandscape
        ? _buildLandscapeContent(bag, voice, colors, ref)
        : Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: bag.isConnected ? Colors.cyanAccent : Colors.white10,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatusIndicator(bag.isConnected),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bag.isConnected
                                        ? "HARDWARE ONLINE"
                                        : "HARDWARE OFFLINE",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    "Protocolo BLE JDY-23",
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              if (bag.isConnected) ...[
                                IconButton(
                                  iconSize: 30,
                                  icon: Icon(
                                    Icons.travel_explore,
                                    color: colors.primary,
                                  ),
                                  onPressed: () => ref
                                      .read(bagControlProvider.notifier)
                                      .activateModeTravel(),
                                ),
                                IconButton(
                                  iconSize: 30,
                                  icon: voice.isListening
                                      ? Icon(
                                          Icons.mic_off,
                                          color: colors.primary,
                                        )
                                      : Icon(Icons.mic, color: colors.primary),
                                  onPressed: () => ref
                                      .read(voiceControllerProvider.notifier)
                                      .toggleMic(),
                                ),
                              ],
                            ],
                          ),
                          if (bag.isConnected)
                            BatteryIndicator(level: bag.batteryLevel ?? 0),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!bag.isConnected) ...[
                  const Divider(height: 30, color: Colors.white10),
                  SizedBox(
                    width: double.infinity,
                    child: bag.isScanning
                        ? Column(
                            children: [
                              const LinearProgressIndicator(), // Barra de progreso sutil M3
                              const SizedBox(height: 8),
                              Text(
                                "Buscando Magic Bag...",
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : FilledButton.icon(
                            onPressed: () => ref
                                .read(bagControlProvider.notifier)
                                .requestPermissions(),
                            icon: const Icon(Icons.bluetooth_searching),
                            label: const Text("INICIAR ESCANEO"),
                          ),
                  ),
                ],
              ],
            ),
          );
  }

  Widget _buildStatusIndicator(bool connected) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? Colors.cyanAccent : Colors.redAccent,
        boxShadow: [
          if (connected)
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
        ],
      ),
    );
  }

  Widget _buildLandscapeContent(
    dynamic bag,
    dynamic voice,
    ColorScheme colors,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatusIndicator(bag.isConnected),
            const SizedBox(width: 12),
            // Solo el título, sin el subtítulo del protocolo
            Text(
              bag.isConnected ? "ONLINE" : "OFFLINE",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Spacer(),
            if (bag.isConnected) ...[
              // Botones más pequeños para no estirar la barra
              _smallIconButton(
                icon: Icons.travel_explore,
                color: colors.primary,
                onPressed: () =>
                    ref.read(bagControlProvider.notifier).activateModeTravel(),
              ),
              const SizedBox(width: 8),
              _smallIconButton(
                icon: voice.isListening ? Icons.mic_off : Icons.mic,
                color: voice.isListening ? Colors.redAccent : colors.primary,
                onPressed: () =>
                    ref.read(voiceControllerProvider.notifier).toggleMic(),
              ),
              const SizedBox(width: 8),
              BatteryIndicator(level: bag.batteryLevel ?? 0),
            ] else if (bag.isScanning) ...[
              const SizedBox(
                width: 80,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () =>
                    ref.read(bagControlProvider.notifier).requestPermissions(),
                icon: const Icon(Icons.bluetooth_searching, size: 18),
                label: const Text("SCAN", style: TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Helper para botones compactos en la barra
  Widget _smallIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }
}
