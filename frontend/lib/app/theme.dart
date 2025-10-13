import 'package:flutter/material.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF2A9D8F),
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF5F7FB),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFF102027),
  ),
  chipTheme: ChipThemeData.fromDefaults(
    secondaryColor: const Color(0xFF2A9D8F),
    brightness: Brightness.light,
    labelStyle: const TextStyle(fontWeight: FontWeight.w500),
  ).copyWith(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  cardTheme: CardTheme(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
  textTheme: Typography.blackMountainView.copyWith(
    titleLarge: const TextStyle(fontWeight: FontWeight.w700),
    titleMedium: const TextStyle(fontWeight: FontWeight.w600),
    labelMedium: const TextStyle(color: Color(0xFF607D8B)),
  ),
);
