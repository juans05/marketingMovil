import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:http/http.dart' as http;

const int kChunkSizeBytes = 10 * 1024 * 1024; // 10MB — Cloudinary minimo 5MB
const int kMaxRetries = 3;

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

/// Tipos de mensajes que el isolate envia al main thread
/// type: 'progress' | 'done' | 'error' | 'log'
class UploadMessage {
  final String type;
  final String? status;
  final double? progress;
  final String? error;
  final String? secureUrl;
  final String? log;

  UploadMessage({
    required this.type,
    this.status,
    this.progress,
    this.error,
    this.secureUrl,
    this.log,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        if (status != null) 'status': status,
        if (progress != null) 'progress': progress,
        if (error != null) 'error': error,
        if (secureUrl != null) 'secureUrl': secureUrl,
        if (log != null) 'log': log,
      };

  factory UploadMessage.fromJson(Map<String, dynamic> json) => UploadMessage(
        type: json['type'] as String,
        status: json['status'] as String?,
        progress: (json['progress'] as num?)?.toDouble(),
        error: json['error'] as String?,
        secureUrl: json['secureUrl'] as String?,
        log: json['log'] as String?,
      );
}

/// Funcion pura que corre en el isolate para subir chunks y registrar video.
/// NO debe usar PlatformChannels (SharedPreferences, video_compress, etc.)
void uploadWorker(Map<String, dynamic> paramsJson) async {
  final sendPort = paramsJson['sendPort'] as SendPort;
  final uploadParams = paramsJson['params'] as Map<String, dynamic>;
  final tStart = DateTime.now();
  send(UploadMessage msg) => sendPort.send(msg.toJson());
  log(String message) {
    final elapsed = DateTime.now().difference(tStart);
    send(UploadMessage(type: 'log', log: '[+${_fmt(elapsed)}] $message'));
  }

  try {
    final filePath = uploadParams['filePath'] as String;
    final artistId = uploadParams['artistId'] as String;
    final title = uploadParams['title'] as String;
    final baseUrl = uploadParams['baseUrl'] as String;
    final authToken = uploadParams['authToken'] as String;
    final sigData = uploadParams['sigData'] as Map<String, dynamic>;
    final uploadId = uploadParams['uploadId'] as String;

    log('🚀 Iniciando upload de "$title"');

    final file = File(filePath);
    if (!await file.exists()) {
      log('❌ Archivo no encontrado: $filePath');
      send(UploadMessage(type: 'error', error: 'Archivo no encontrado: $filePath'));
      return;
    }

    final fileSize = await file.length();
    final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
    final totalChunks = (fileSize / kChunkSizeBytes).ceil();
    final cloudName = sigData['cloudName'] as String;
    final resourceType = sigData['resourceType'] as String? ?? 'video';
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

    log('📦 Tamaño: ${fileSizeMB}MB | Chunks: $totalChunks (10MB c/u)');
    log('☁️  Destino: $cloudName/$resourceType');

    String? secureUrl;

    for (var i = 0; i < totalChunks; i++) {
      final tChunk = DateTime.now();
      final start = i * kChunkSizeBytes;
      final end = min(start + kChunkSizeBytes - 1, fileSize - 1);
      final chunkSizeMB = ((end - start + 1) / 1024 / 1024).toStringAsFixed(2);
      log('⬆️  Chunk ${i + 1}/$totalChunks (${chunkSizeMB}MB) — subiendo...');

      final chunkBytes = await readChunk(file, start, end - start + 1);

      secureUrl = await uploadChunkWithRetry(
        uri: uri,
        chunkBytes: chunkBytes,
        sigData: sigData,
        uploadId: uploadId,
        start: start,
        end: end,
        fileSize: fileSize,
      );

      final chunkElapsed = DateTime.now().difference(tChunk);
      final speedMBps = ((end - start + 1) / 1024 / 1024) / (chunkElapsed.inMilliseconds / 1000);
      log('✅ Chunk ${i + 1}/$totalChunks listo (${_fmt(chunkElapsed)}, ${speedMBps.toStringAsFixed(2)} MB/s)');

      final progress = (i + 1) / totalChunks;
      send(UploadMessage(
        type: 'progress',
        status: 'uploading',
        progress: 0.1 + (progress * 0.85),
      ));
    }

    if (secureUrl == null) {
      log('❌ Cloudinary no retornó secure_url');
      send(UploadMessage(type: 'error', error: 'Upload completado sin retornar secure_url'));
      return;
    }

    log('🔗 Video en Cloudinary: $secureUrl');
    send(UploadMessage(type: 'progress', status: 'registering', progress: 0.97));
    log('📝 Registrando video en backend...');

    final tRegister = DateTime.now();
    final registerOk = await registerVideo(
      baseUrl: baseUrl,
      authToken: authToken,
      artistId: artistId,
      sourceUrl: secureUrl,
      title: title,
    );
    log('✅ Backend registrado (${_fmt(DateTime.now().difference(tRegister))})');

    if (!registerOk) {
      log('❌ Fallo al registrar en backend');
      send(UploadMessage(type: 'error', error: 'No se pudo registrar el video en el servidor'));
      return;
    }

    final total = DateTime.now().difference(tStart);
    log('🎉 Completado en ${_fmt(total)}');
    send(UploadMessage(type: 'done', progress: 1.0, secureUrl: secureUrl));
  } catch (e) {
    log('💥 Excepción: $e');
    send(UploadMessage(type: 'error', error: e.toString()));
  }
}

/// Funcion pura para subir un remote URL (Path B)
void uploadFromUrlWorker(Map<String, dynamic> paramsJson) async {
  final sendPort = paramsJson['sendPort'] as SendPort;
  send(UploadMessage msg) => sendPort.send(msg.toJson());

  try {
    final remoteUrl = paramsJson['remoteUrl'] as String;
    final artistId = paramsJson['artistId'] as String;
    final title = paramsJson['title'] as String;
    final baseUrl = paramsJson['baseUrl'] as String;
    final authToken = paramsJson['authToken'] as String;

    send(UploadMessage(type: 'progress', status: 'registering', progress: 0.2));

    final ok = await uploadFromUrlApi(
      baseUrl: baseUrl,
      authToken: authToken,
      artistId: artistId,
      remoteUrl: remoteUrl,
      title: title,
    );

    if (!ok) {
      send(UploadMessage(type: 'error', error: 'No se pudo registrar el video desde URL'));
      return;
    }

    send(UploadMessage(type: 'done', progress: 1.0));
  } catch (e) {
    send(UploadMessage(type: 'error', error: e.toString()));
  }
}

// ── Helper functions (pure, no platform channels) ─────────────────────────────

Future<Uint8List> readChunk(File file, int start, int length) async {
  final raf = await file.open();
  try {
    await raf.setPosition(start);
    return await raf.read(length);
  } finally {
    await raf.close();
  }
}

Future<String?> uploadChunkWithRetry({
  required Uri uri,
  required Uint8List chunkBytes,
  required Map<String, dynamic> sigData,
  required String uploadId,
  required int start,
  required int end,
  required int fileSize,
}) async {
  Exception? lastError;

  for (var attempt = 0; attempt < kMaxRetries; attempt++) {
    if (attempt > 0) {
      await Future.delayed(Duration(seconds: pow(2, attempt - 1).toInt()));
    }
    try {
      return await uploadChunk(
        uri: uri,
        chunkBytes: chunkBytes,
        sigData: sigData,
        uploadId: uploadId,
        start: start,
        end: end,
        fileSize: fileSize,
      );
    } on Exception catch (e) {
      lastError = e;
    }
  }

  throw lastError!;
}

Future<String?> uploadChunk({
  required Uri uri,
  required Uint8List chunkBytes,
  required Map<String, dynamic> sigData,
  required String uploadId,
  required int start,
  required int end,
  required int fileSize,
}) async {
  final request = http.MultipartRequest('POST', uri);

  request.headers['X-Unique-Upload-Id'] = uploadId;
  request.headers['Content-Range'] = 'bytes $start-$end/$fileSize';

  request.fields['api_key'] = sigData['apiKey'].toString();
  request.fields['timestamp'] = sigData['timestamp'].toString();
  request.fields['signature'] = sigData['signature'].toString();
  request.fields['folder'] = sigData['folder'].toString();

  if (sigData['eager'] != null) {
    request.fields['eager'] = sigData['eager'].toString();
  }
  if (sigData['access_mode'] != null) {
    request.fields['access_mode'] = sigData['access_mode'].toString();
  } else {
    request.fields['access_mode'] = 'public';
  }

  request.files.add(http.MultipartFile.fromBytes(
    'file',
    chunkBytes,
    filename: 'chunk',
  ));

  final streamed = await request.send().timeout(const Duration(seconds: 90));
  final response = await http.Response.fromStream(streamed);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Chunk upload fallido: ${response.statusCode} — ${response.body}');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return body['secure_url'] as String?;
}

Future<bool> registerVideo({
  required String baseUrl,
  required String authToken,
  required String artistId,
  required String sourceUrl,
  required String title,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/vidalis/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'videoData': {
          'artist_id': artistId,
          'source_url': sourceUrl,
          'status': 'analyzing',
          'title': title,
        }
      }),
    ).timeout(const Duration(seconds: 30));

    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}

Future<bool> uploadFromUrlApi({
  required String baseUrl,
  required String authToken,
  required String artistId,
  required String remoteUrl,
  required String title,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/vidalis/videos/from-url'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'artist_id': artistId,
        'remote_url': remoteUrl,
        'title': title,
      }),
    ).timeout(const Duration(seconds: 30));

    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}
