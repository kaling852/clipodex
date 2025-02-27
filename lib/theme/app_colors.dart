import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primaryLight = Color(0xFFFF6D36); // Rolex Explorer II orange
  static const Color secondaryLight = Color(0xFFFF8D5C); // Lighter shade of the orange
  
  // Background colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color inputBackground = Color(0xFF2C2C2C);
  
  // Text colors
  static const Color textPrimary = Color(0xFFE0E0E0);    // Less bright white
  static const Color textSecondary = Color(0xFFB0B0B0);  // Softer secondary text
  static const Color textContent = Color(0xFFCCCCCC);    // Lighter than secondary for commands
  static const Color hintText = Colors.grey;
  static const Color buttonText = Color(0xFF1A1A1A); // Matte black for button text

  // Get the color scheme
  static ColorScheme get colorScheme => ColorScheme.dark(
    primary: primaryLight,
    secondary: secondaryLight,
    surface: surface,
    background: background,
  );

  // Get the theme data
  static ThemeData get themeData => ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    cardColor: surface,
    dialogBackgroundColor: surface,
    
    // Add cursor color
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: textSecondary,
      selectionColor: textSecondary.withOpacity(0.3),
      selectionHandleColor: textSecondary,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      hintStyle: TextStyle(color: hintText),
      labelStyle: TextStyle(color: textPrimary),
      floatingLabelStyle: TextStyle(color: textPrimary),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: textSecondary),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: buttonText, // Using matte black for text
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
    
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        fontWeight: FontWeight.bold,  // Bold for card titles
      ),
      bodyMedium: TextStyle(
        color: textContent,  // Lighter color for command content
      ),
      bodySmall: TextStyle(
        color: textSecondary,  // Keep date color softer
      ),
    ),
    
    useMaterial3: true,
  );
} 