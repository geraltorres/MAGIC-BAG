import 'package:flutter/material.dart';

class AppTheme {
  // Colores base de la marca "Tech"
  static const _brandCyan = Color(0xFF006064); // Cyan profundo para Light
  static const _neonCyan = Color(0xFF00E5FF); // Cyan neón para Dark
  static const _warningOrange = Colors.orangeAccent;

  // --- TEMA CLARO (Optimizado para sol directo) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandCyan,
        brightness: Brightness.light,
        surface: Colors.white,
        onSurface: const Color(0xFF1A1C1E), // Negro profundo
        primary: _brandCyan,
        primaryContainer: const Color(0xFFCBF1F5), // Fondo botón activo
        onPrimaryContainer: const Color(0xFF002021), // Texto botón activo
        secondary: _warningOrange,
        surfaceContainerHighest: const Color(
          0xFFF0F2F5,
        ), // Fondo botón inactivo (Gris claro)
        onSurfaceVariant: const Color(0xFF44474E), // Texto botón inactivo
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1C1E),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFF7F9FC),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE1E3E8)),
        ),
      ),
    );
  }

  // --- TEMA OSCURO (Estilo Terminal / GitHub Dark) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _neonCyan,
        brightness: Brightness.dark,
        surface: const Color(0xFF0D1117),
        onSurface: Colors.white,
        primary: _neonCyan,
        primaryContainer: const Color(0xFF004D40),
        onPrimaryContainer: _neonCyan,
        secondary: _warningOrange,
        surfaceContainerHighest: const Color(0xFF161B22),
        onSurfaceVariant: const Color(0xFF8B949E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
