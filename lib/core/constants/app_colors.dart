import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand (Neon & Viral Vibes)
  static const Color primary = Color(0xFF00F2EA); // Cyan Neon
  static const Color accent = Color(0xFFE1306C);  // Magenta Neon

  // Backgrounds (Carbon Dark)
  static const Color bgPrimary = Color(0xFF070709);
  static const Color bgSecondary = Color(0xFF0A0A0C);
  static const Color bgCard = Color(0xB315151A); // Translucent for glass effect
  static const Color bgInput = Color(0xFF15151A);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Border
  static const Color border = Color(0x33FFFFFF); // Light transluscent border
  static const Color borderFocus = Color(0xFF00F2EA);

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
  static BoxDecoration glassCard({double radius = 20}) => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration primaryGlow({double radius = 16}) => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 0),
          ),
        ],
      );

  // Viral score gamified colors
  static Color viralScoreColor(double score) {
    if (score >= 9) return const Color(0xFF00F2EA); // Diamond / God Tier
    if (score >= 7) return const Color(0xFFFBBF24); // Gold / Viral
    if (score >= 5) return const Color(0xFF22C55E); // Green / Good
    if (score >= 3) return const Color(0xFFF97316); // Orange / Warning
    return const Color(0xFFEF4444); // Red / Bad
  }
}
