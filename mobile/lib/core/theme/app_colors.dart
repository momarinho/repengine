import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds & Surfaces
  static const background = Color(0xFF14121E);
  static const surface = Color(0xFF14121E);
  static const surfaceDim = Color(0xFF14121E);
  static const surfaceBright = Color(0xFF3A3746);

  // Surface Containers (Camadas de elevação M3)
  static const surfaceContainerLowest = Color(0xFF0E0D19);
  static const surfaceContainerLow = Color(0xFF1C1A27);
  static const surfaceContainer = Color(0xFF201E2B);
  static const surfaceContainerHigh = Color(0xFF2B2836);
  static const surfaceContainerHighest = Color(0xFF353341);

  // Primary (Rosa / Rose Accent)
  static const primary = Color(0xFFFFB1C3);
  static const primaryContainer = Color(0xFFEB6F92);
  static const onPrimary = Color(0xFF65012C);
  static const onPrimaryContainer = Color(0xFF64012C);

  // Secondary (Lavanda / Roxo Suave)
  static const secondary = Color(0xFFD8BAFB);
  static const secondaryContainer = Color(0xFF543B73);
  static const onSecondary = Color(0xFF3C245B);
  static const onSecondaryContainer = Color(0xFFC6A9E9);

  // Tertiary (Cyan / Foam Accent)
  static const tertiary = Color(0xFF9CCFD8);
  static const tertiaryContainer = Color(0xFF6EA0A8);
  static const onTertiary = Color(0xFF00363D);

  // Textos & Destaques
  static const onBackground = Color(0xFFE5E0F3);
  static const onSurface = Color(0xFFE5E0F3);
  static const onSurfaceVariant = Color(0xFFDBC0C4);

  // Bordas & Divisores
  static const outline = Color(0xFFA38B8F);
  static const outlineVariant = Color(0xFF554246);

  // Status & Erro
  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);
  static const onError = Color(0xFF690005);
  static const success = Color(0xFF98BB6C);
}
