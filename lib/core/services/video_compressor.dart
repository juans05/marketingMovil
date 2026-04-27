import 'package:video_compress/video_compress.dart';

class VideoCompressor {
  static Future<String> compress(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    Subscription? sub;
    if (onProgress != null) {
      sub = VideoCompress.compressProgress$.subscribe((p) {
        onProgress(p / 100.0);
      });
    }

    try {
      final info = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality, // Más rápido que DefaultQuality
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info == null || info.path == null) {
        throw Exception('La compresión devolvió un resultado vacío');
      }

      return info.path!;
    } finally {
      sub?.unsubscribe();
    }
  }

  static Future<void> cancelCompression() async {
    await VideoCompress.cancelCompression();
  }
}
