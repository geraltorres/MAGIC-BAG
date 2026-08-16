import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_bag/core/constants/arduino_constants.dart';
import 'package:magic_bag/core/enums/selection_source.dart';
import 'package:magic_bag/domain/entities/bag_status.dart';
import 'package:magic_bag/presentation/animations/pulsar_animation.dart';
import 'package:magic_bag/presentation/widgets/mini_bag_widget.dart';
import 'package:magic_bag/providers/bag_control/bag_provider.dart';
import 'package:magic_bag/providers/bluetooth/repository_provider.dart';
import 'package:magic_bag/providers/microphone/voice_provider.dart';
import 'package:magic_bag/providers/ui/theme_provider.dart';
import 'package:flutter/services.dart';

import '../widgets/status_panel.dart';
import '../components/action_button.dart';

class ControlPage extends ConsumerWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el estado del provider generado por Riverpod
    final bagState = ref.watch(bagControlProvider);
    final notifier = ref.read(bagControlProvider.notifier);

    final themeMode = ref.watch(themeControlProvider);
    final themeNotifier = ref.read(themeControlProvider.notifier);

    registerAssistantShortcut();

    // Detectamos la orientación actual
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    ref.listen<BagStatus>(bagControlProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: "REINTENTAR",
              onPressed: () =>
                  ref.read(bagControlProvider.notifier).requestPermissions(),
              textColor: Colors.white,
            ),
          ),
        );
      }
    });

    ref.listen<BagStatus>(bagControlProvider, (previous, next) {
      if (previous?.isConnected == next.isConnected) return;

      if (next.isConnected) {
        print("Maleta conectada: Iniciando Vosk...");
        ref.read(voiceControllerProvider.notifier).initVosk();
      } else {
        print("Maleta desconectada: Forzando Stop...");
        // CORRECCIÓN: Si está activo (true), lo apagamos.
        if (ref.read(voiceControllerProvider).isListening) {
          ref.read(voiceControllerProvider.notifier).stop();
        }
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        // Si el ancho es menor a 200px, estamos en PiP
        bool isPip = constraints.maxWidth < 200;
        return Scaffold(
          appBar: AppBar(
            title: const Text("MAGIC BAG TERMINAL"),
            actions: [
              // Botón de cambio de tema dinámico
              IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => themeNotifier.toggleTheme(),
                tooltip: "Cambiar apariencia",
              ),
              if (bagState.isConnected)
                IconButton(
                  icon: const Icon(
                    Icons.bluetooth_disabled,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => ref.read(bagRepositoryProvider).disconnect(),
                ),
            ],
          ),
          body: isPip
              ? _buildMiniMode()
              : isLandscape
              ? _buildLandscapeLayout(context, bagState, notifier)
              : _buildPortraitLayout(context, bagState, notifier),
        );
      },
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    BagStatus bagState,
    BagControl notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PANEL IZQUIERDO: Botones de comando
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const StatusPanel(),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.count(
                    padding: EdgeInsets.symmetric(
                      horizontal: bagState.isConnected ? 30 : 38,
                    ),
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.8, // Más estirados para caber mejor
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: _buildActionButtons(bagState, notifier),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // PANEL DERECHO: Telemetría y Animación
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    PulseAnimation(
                      activeMode: bagState.activeMode,
                      isConnected: bagState.isConnected,
                    ),
                    Icon(
                      Icons.directions_bike,
                      size: 60, // Un poco más pequeño para landscape
                      color: bagState.isConnected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white24,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildModeFooter(bagState, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    BagStatus bagState,
    BagControl notifier,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel de conexión y estado del hardware
            const StatusPanel(),

            const SizedBox(height: 12),
            const Text(
              "CONTROL DE ILUMINACIÓN",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Grid de comandos para el Arduino Nano
            Expanded(
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: _buildActionButtons(bagState, notifier),
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                // La animación de fondo (Core de la experiencia visual)
                PulseAnimation(
                  activeMode: bagState.activeMode,
                  isConnected: bagState.isConnected,
                ),

                // El icono de la maleta que indica el estado
                Icon(
                  Icons
                      .directions_bike, // O el icono que prefieras para la ruta
                  size: 80,
                  color: bagState.isConnected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                ),
              ],
            ),
            // Indicador de modo actual (Telemetría básica)
            _buildModeFooter(bagState, context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BagStatus bagState, BagControl notifier) {
    return [
      ActionButton(
        title: "FIJO",
        icon: Icons.lightbulb,
        isActive: bagState.activeMode == ArduinoConstants.cmdOn,
        onTap: () => notifier.sendCommand(
          ArduinoConstants.cmdOn,
          source: SelectionSource.manual,
        ),
      ),
      ActionButton(
        title: "RUTA",
        icon: Icons.motorcycle,
        isActive: bagState.activeMode == ArduinoConstants.cmdRoute,
        onTap: () => notifier.sendCommand(
          ArduinoConstants.cmdRoute,
          source: SelectionSource.manual,
        ),
      ),
      ActionButton(
        title: "RÍTMICO",
        icon: Icons.graphic_eq,
        isActive: bagState.activeMode == ArduinoConstants.cmdMusic,
        onTap: () => notifier.sendCommand(
          ArduinoConstants.cmdMusic,
          source: SelectionSource.manual,
        ),
      ),
      ActionButton(
        title: "APAGAR",
        icon: Icons.power_settings_new,
        isActive: bagState.activeMode == ArduinoConstants.cmdOff,
        onTap: () => notifier.sendCommand(
          ArduinoConstants.cmdOff,
          source: SelectionSource.manual,
        ),
      ),
    ];
  }

  Widget _buildModeFooter(bagState, context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        "MODO ACTIVO: ${bagState.activeMode == '0' ? 'STANDBY' : 'EJECUTANDO (${bagState.activeMode})'}",
        style: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .primary, // Ahora será cyan oscuro en light y neón en dark
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> registerAssistantShortcut() async {
    const platform = MethodChannel('com.lonewolf.magicbag/shortcuts');
    try {
      await platform.invokeMethod('registerShortcut', {
        'id': 'modo_ruta',
        'shortLabel': 'Activar Modo Ruta',
        'intentUri': 'magicbag://control?mode=ruta',
      });
    } on PlatformException catch (e) {
      print("Error registrando shortcut: ${e.message}");
    }
  }

  Widget _buildMiniMode() {
    return MiniBagWidget();
  }
}
