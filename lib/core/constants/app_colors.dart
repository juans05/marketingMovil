import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF4F46E5);
  static const Color accent = Color(0xFFA855F7);

  // Backgrounds
  static const Color bgPrimary = Color(0xFF09090B);
  static const Color bgSecondary = Color(0xFF121214);
  static const Color bgCard = Color(0xFF18181B);
  static const Color bgInput = Color(0xFF1C1C1F);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF71717A);
  static const Color textMuted = Color(0xFF52525B);

  // Border
  static const Color border = Color(0xFF27272A);
  static const Color borderFocus = Color(0xFF4F46E5);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Platforms
  static const Color tiktok = Color(0xFF000000);
  static const Color instagram = Color(0xFFE1306C);
  static const Color youtube = Color(0xFFFF0000);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [bgPrimary, bgSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Decorations
  static BoxDecoration glassCard({double radius = 16}) => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
      );

  static BoxDecoration primaryGlow({double radius = 16}) => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // Viral score color
  static Color viralScoreColor(double score) {
    if (score >= 8) return const Color(0xFF22C55E);
    if (score >= 6) return const Color(0xFF84CC16);
    if (score >= 4) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
