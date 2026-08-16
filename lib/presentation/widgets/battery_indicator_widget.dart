import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final int level;

  const BatteryIndicator({super.key, required this.level});

  Color _getBatteryColor() {
    if (level > 60) return Colors.greenAccent;
    if (level > 20) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          level > 10 ? Icons.battery_charging_full : Icons.battery_alert,
          color: _getBatteryColor(),
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          "$level%",
          style: TextStyle(
            color: _getBatteryColor(),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
