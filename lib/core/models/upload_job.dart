enum UploadStatus { preparing, compressing, uploading, registering, done, failed }

class UploadLogEntry {
  final DateTime timestamp;
  final String message;
  const UploadLogEntry(this.timestamp, this.message);
}

class UploadJob {
  final String id;
  final String artistId;
  final String? title;
  final String? filePath;
  final UploadStatus status;
  final double progress;
  final int completedChunks;
  final int totalChunks;
  final String? cloudinaryUrl;
  final String? errorMessage;
  final List<UploadLogEntry> logs;
  final DateTime startedAt;

  UploadJob({
    required this.id,
    required this.artistId,
    this.title,
    this.filePath,
    this.status = UploadStatus.preparing,
    this.progress = 0.0,
    this.completedChunks = 0,
    this.totalChunks = 0,
    this.cloudinaryUrl,
    this.errorMessage,
    List<UploadLogEntry>? logs,
    DateTime? startedAt,
  })  : logs = logs ?? <UploadLogEntry>[],
        startedAt = startedAt ?? DateTime.now();

  bool get isActive =>
      status == UploadStatus.preparing ||
      status == UploadStatus.compressing ||
      status == UploadStatus.uploading ||
      status == UploadStatus.registering;

  String get statusLabel {
    switch (status) {
      case UploadStatus.preparing:
        return 'Preparando...';
      case UploadStatus.compressing:
        return 'Comprimiendo video...';
      case UploadStatus.uploading:
        return 'Subiendo ${(progress * 100).toInt()}%';
      case UploadStatus.registering:
        return 'Procesando...';
      case UploadStatus.done:
        return '¡Video subido!';
      case UploadStatus.failed:
        return 'Error al subir';
    }
  }

  UploadJob copyWith({
    String? id,
    String? artistId,
    String? title,
    String? filePath,
    UploadStatus? status,
    double? progress,
    int? completedChunks,
    int? totalChunks,
    String? cloudinaryUrl,
    String? errorMessage,
    List<UploadLogEntry>? logs,
    DateTime? startedAt,
  }) {
    return UploadJob(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      completedChunks: completedChunks ?? this.completedChunks,
      totalChunks: totalChunks ?? this.totalChunks,
      cloudinaryUrl: cloudinaryUrl ?? this.cloudinaryUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      logs: logs ?? this.logs,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  UploadJob withLog(String message) {
    final newLogs = List<UploadLogEntry>.from(logs)
      ..add(UploadLogEntry(DateTime.now(), message));
    return copyWith(logs: newLogs);
  }
}
