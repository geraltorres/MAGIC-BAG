import 'package:flutter/material.dart';
import 'package:magic_bag/core/constants/arduino_constants.dart';

class PulseAnimation extends StatefulWidget {
  final String activeMode;
  final bool isConnected;

  const PulseAnimation({
    super.key,
    required this.activeMode,
    required this.isConnected,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia el modo, ajustamos la velocidad de la animación en tiempo real
    if (oldWidget.activeMode != widget.activeMode) {
      _updateAnimationSpeed();
    }
  }

  void _updateAnimationSpeed() {
    Duration newDuration;
    switch (widget.activeMode) {
      case ArduinoConstants.cmdRoute: // MODO FLASH / RUTA
        newDuration = const Duration(milliseconds: 400);
        break;
      case ArduinoConstants.cmdMusic: // MODO PULSO
        newDuration = const Duration(milliseconds: 100);
        break;
      case ArduinoConstants.cmdOn: // MODO FIJO
        _controller.forward(from: 3);
        return;
      default:
        newDuration = const Duration(milliseconds: 1500);
        _controller.reset();
        return;
    }
    _controller.duration = newDuration;
    if (widget.isConnected) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected) return const SizedBox.shrink();

    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
