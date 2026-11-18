import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';

abstract final class LilyTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Sniglet',
    scaffoldBackgroundColor: cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: plum,
      surface: cream,
      primary: plum,
      secondary: sage,
      onSurface: plum,
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: plum,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(fontFamily: 'Sniglet', color: plum),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 36, height: 1.16, color: plum),
      headlineMedium: TextStyle(fontSize: 30, height: 1.2, color: plum),
      titleLarge: TextStyle(fontSize: 22, height: 1.3, color: plum),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: plum),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: inkSoft),
      labelLarge: TextStyle(fontSize: 16, color: plum),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: plum,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: inkSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFDCD4DF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: coral, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: plum,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 54),
        textStyle: const TextStyle(fontFamily: 'Sniglet', fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: plum,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
