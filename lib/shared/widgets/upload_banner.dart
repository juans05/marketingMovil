import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_compress/video_compress.dart';
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
          top: MediaQuery.of(context).padding.top + 70, // debajo del AppBar
          left: 12,
          child: _UploadChip(job: job),
        );
      },
    );
  }
}

class _UploadChip extends StatefulWidget {
  const _UploadChip({required this.job});
  final UploadJob job;

  @override
  State<_UploadChip> createState() => _UploadChipState();
}

class _UploadChipState extends State<_UploadChip> {
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final path = widget.job.filePath;
    if (path == null) return;
    try {
      final file = await VideoCompress.getFileThumbnail(path, quality: 30);
      if (mounted) setState(() => _thumbnailPath = file.path);
    } catch (_) {
      // Si falla, dejamos el placeholder
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final isDone = job.status == UploadStatus.done;
    final isFailed = job.status == UploadStatus.failed;
    final percent = (job.progress * 100).clamp(0, 100).toInt();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 76,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail o placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _thumbnailPath != null
                  ? Image.file(
                      File(_thumbnailPath!),
                      fit: BoxFit.cover,
                      width: 76,
                      height: 100,
                    )
                  : Container(
                      color: AppColors.bgCard,
                      child: const Center(
                        child: Icon(Icons.videocam_outlined,
                            color: AppColors.textMuted, size: 28),
                      ),
                    ),
            ),
            // Overlay oscuro para legibilidad
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black.withValues(alpha: isDone ? 0.3 : 0.55),
              ),
            ),
            // Estado: progreso, check, o error
            if (isFailed)
              const Icon(Icons.error_outline, color: Colors.white, size: 32)
            else if (isDone)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              )
            else
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        value: job.progress > 0 ? job.progress : null,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    Text(
                      job.progress > 0 ? '$percent%' : '...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            // Borde con color de estado
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFailed
                      ? AppColors.danger
                      : isDone
                          ? const Color(0xFF10B981)
                          : AppColors.primary.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
