import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.title,
    required this.icon,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // El color del fondo del botón
    final backgroundColor = isActive
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    // El color del icono y el texto
    final foregroundColor = isActive
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant; // Esto garantiza legibilidad en gris/claro

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(isLandscape ? 16 : 24),
          border: Border.all(
            color: isActive ? Colors.cyanAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: isLandscape
            ? Row(
                // En horizontal, ponemos icono y texto lado a lado
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: foregroundColor,
                  ), // Icono más pequeño
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      overflow:
                          TextOverflow.ellipsis, // Por si el nombre es largo
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 42, color: foregroundColor),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
