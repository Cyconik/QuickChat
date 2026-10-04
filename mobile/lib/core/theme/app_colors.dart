import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette: Deep Space & Cyberpunk/Neon Mesh accents
  static const Color background = Color(0xFF0B0E17); // Deepest cosmic navy
  static const Color surface = Color(0xFF131826); // Elevated card background
  static const Color surfaceLight = Color(0xFF1B2238); // Border & subtle surface
  static const Color surfaceHighlight = Color(0xFF242F4D);

  // Accent & Glow Colors
  static const Color primary = Color(0xFF00E5FF); // Electric Cyan
  static const Color primaryGlow = Color(0x3300E5FF);
  static const Color secondary = Color(0xFF7C4DFF); // Deep Violet / Electric Purple
  static const Color secondaryGlow = Color(0x337C4DFF);
  static const Color accent = Color(0xFF00F59B); // Neon Mint / Online indicator
  static const Color warning = Color(0xFFFFB300); // Amber warning
  static const Color error = Color(0xFFFF3366); // Neon Crimson error

  // Text Colors
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFF050B14);

  // Mesh Status Indicators
  static const Color meshActive = Color(0xFF00F59B);
  static const Color meshRelaying = Color(0xFF00E5FF);
  static const Color meshIdle = Color(0xFF64748B);
  static const Color meshDisconnected = Color(0xFFFF3366);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF161D2F), Color(0xFF101524)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshNodeGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00F59B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
