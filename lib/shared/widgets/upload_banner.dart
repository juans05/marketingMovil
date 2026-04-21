import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/upload_job.dart';
import '../../core/services/upload_queue.dart';

class UploadBannerOverlay extends StatelessWidget {
  const UploadBannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadQueue>(
      builder: (context, queue, _) {
        final job = queue.activeJob;
        if (job == null) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _UploadBanner(job: job),
        );
      },
    );
  }
}

class _UploadBanner extends StatelessWidget {
  const _UploadBanner({required this.job});
  final UploadJob job;

  @override
  Widget build(BuildContext context) {
    final isDone = job.status == UploadStatus.done;
    final isFailed = job.status == UploadStatus.failed;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isFailed
              ? AppColors.danger.withValues(alpha: 0.95)
              : isDone
                  ? const Color(0xFF10B981).withValues(alpha: 0.95)
                  : AppColors.bgCard.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFailed
                ? AppColors.danger
                : isDone
                    ? const Color(0xFF10B981)
                    : AppColors.primary.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _icon(isDone, isFailed),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    job.title ?? 'Video',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFailed
                        ? (job.errorMessage ?? 'Error al subir')
                        : job.statusLabel,
                    style: TextStyle(
                      color: isFailed ? Colors.white : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (job.isActive && !isDone) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: job.progress > 0 ? job.progress : null,
                        backgroundColor: AppColors.border,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(bool isDone, bool isFailed) {
    if (isFailed) {
      return const Icon(Icons.error_outline, color: Colors.white, size: 20);
    }
    if (isDone) {
      return const Icon(Icons.check_circle_outline, color: Colors.white, size: 20);
    }
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(AppColors.primary),
      ),
    );
  }
}
