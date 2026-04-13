import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum VidalisButtonVariant { primary, outlined, danger }

class VidalisButton extends StatelessWidget {
  const VidalisButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = VidalisButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final VidalisButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    Widget child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: _iconColor),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ],
    );

    if (variant == VidalisButtonVariant.primary) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        child: DecoratedBox(
          decoration: disabled
              ? BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(12),
                )
              : AppColors.primaryGlow(radius: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(
            color: variant == VidalisButtonVariant.danger
                ? AppColors.danger
                : AppColors.border,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: child,
      ),
    );
  }

  Color get _textColor {
    if (variant == VidalisButtonVariant.danger) return AppColors.danger;
    return AppColors.textPrimary;
  }

  Color get _iconColor {
    if (variant == VidalisButtonVariant.danger) return AppColors.danger;
    if (variant == VidalisButtonVariant.outlined) return AppColors.textSecondary;
    return AppColors.textPrimary;
  }
}
