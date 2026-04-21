import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ChunkedUploader {
  static const int chunkSizeBytes = 6 * 1024 * 1024; // 6MB
  static const int _maxRetries = 3;

  final http.Client _client;

  ChunkedUploader({http.Client? client}) : _client = client ?? http.Client();

  Future<String> upload({
    required String filePath,
    required Map<String, dynamic> sigData,
    required String uploadId,
    int startChunk = 0,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSizeBytes).ceil();
    final cloudName = sigData['cloudName'] as String;
    final resourceType = sigData['resourceType'] as String? ?? 'video';
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

    String? secureUrl;

    for (var i = startChunk; i < totalChunks; i++) {
      final start = i * chunkSizeBytes;
      final end = min(start + chunkSizeBytes - 1, fileSize - 1);
      final chunkBytes = await _readChunk(file, start, end - start + 1);

      secureUrl = await _uploadChunkWithRetry(
        uri: uri,
        chunkBytes: chunkBytes,
        sigData: sigData,
        uploadId: uploadId,
        start: start,
        end: end,
        fileSize: fileSize,
      );

      onProgress?.call((i + 1) / totalChunks);
    }

    if (secureUrl == null) {
      throw Exception('Upload completado sin retornar secure_url');
    }
    return secureUrl;
  }

  Future<Uint8List> _readChunk(File file, int start, int length) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }

  Future<String?> _uploadChunkWithRetry({
    required Uri uri,
    required Uint8List chunkBytes,
    required Map<String, dynamic> sigData,
    required String uploadId,
    required int start,
    required int end,
    required int fileSize,
  }) async {
    Exception? lastError;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: pow(2, attempt - 1).toInt()));
      }
      try {
        return await _uploadChunk(
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

  Future<String?> _uploadChunk({
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

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      chunkBytes,
      filename: 'chunk',
    ));

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Chunk upload falló: ${response.statusCode} — ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['secure_url'] as String?;
  }
}
