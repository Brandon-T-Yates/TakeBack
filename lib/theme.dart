import 'package:flutter/material.dart';

const ink = Color(0xFF203D36);
const canvas = Color(0xFFF7F6F2);
const muted = Color(0xFF626C66);
const softGreen = Color(0xFFE7EDE5);

ThemeData takeBackTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    surface: canvas,
    onSurface: ink,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: canvas,
    textTheme: base.textTheme.copyWith(
      displaySmall: const TextStyle(
        fontSize: 44,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.8,
        color: ink,
      ),
      headlineMedium: const TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.9,
        color: ink,
      ),
      bodyLarge: const TextStyle(fontSize: 17, height: 1.55, color: muted),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.5, color: muted),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      titleSpacing: 24,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 58),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}
