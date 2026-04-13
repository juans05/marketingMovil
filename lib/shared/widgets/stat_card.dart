import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final String? change;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isPositive = change != null && change!.startsWith('+');
    final changeColor = isPositive ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (icon != null)
                Icon(icon, color: iconColor ?? AppColors.primary, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change!,
              style: TextStyle(
                color: changeColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ViralScoreBadge extends StatelessWidget {
  const ViralScoreBadge({super.key, required this.score, this.size = 56});

  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.viralScoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 10,
            strokeWidth: 3,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SocialPlatformChip extends StatelessWidget {
  const SocialPlatformChip({
    super.key,
    required this.platform,
    required this.connected,
  });

  final String platform;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _platformData();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: connected ? color.withOpacity(0.15) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connected ? color.withOpacity(0.5) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: connected ? color : AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: connected ? color : AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _platformData() {
    switch (platform.toLowerCase()) {
      case 'tiktok':
        return (Icons.music_note, 'TikTok', const Color(0xFF00F2EA));
      case 'instagram':
        return (Icons.camera_alt, 'Instagram', const Color(0xFFE1306C));
      case 'youtube':
        return (Icons.play_circle_fill, 'YouTube', const Color(0xFFFF0000));
      default:
        return (Icons.link, platform, AppColors.textSecondary);
    }
  }
}
