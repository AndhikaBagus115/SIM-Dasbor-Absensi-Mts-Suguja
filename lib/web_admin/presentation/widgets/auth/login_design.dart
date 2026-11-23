import 'package:flutter/material.dart';

/// Local to authentication screens; the administration workspace keeps its theme.
abstract final class LoginDesign {
  static const ink = Color(0xFF203B32);
  static const forest = Color(0xFF245B45);
  static const forestDark = Color(0xFF173F30);
  static const muted = Color(0xFF626E66);
  static const paper = Color(0xFFF1F4EE);
  static const border = Color(0xFFD5DDD5);
  static const error = Color(0xFFB53E38);
  static const sans = 'InstrumentSans';
  static const serif = 'InstrumentSerif';

  static ThemeData theme(ThemeData base) => base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: forest,
      secondary: forest,
      surface: Colors.white,
      onSurface: ink,
      error: error,
    ),
    scaffoldBackgroundColor: Colors.white,
    textTheme: base.textTheme.apply(
      fontFamily: sans,
      bodyColor: ink,
      displayColor: ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: const TextStyle(fontFamily: sans, color: muted, fontSize: 14),
      enabledBorder: _outline(border),
      disabledBorder: _outline(border),
      focusedBorder: _outline(forest, 1.5),
      errorBorder: _outline(error),
      focusedErrorBorder: _outline(error, 1.5),
      errorStyle: const TextStyle(fontFamily: sans, fontSize: 12, color: error),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: forest,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontFamily: sans,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: sans,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
  );

  static OutlineInputBorder _outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  static InputDecoration accountField(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19, color: muted),
        labelStyle: const TextStyle(
          fontFamily: sans,
          color: muted,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: sans,
          color: forest,
          fontSize: 14,
        ),
      );
}
