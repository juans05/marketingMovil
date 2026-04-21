import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vidalis_mobile/core/services/chunked_uploader.dart';

void main() {
  group('ChunkedUploader', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('chunked_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('uploads single chunk and returns secure_url', () async {
      // Archivo pequeño (< 6MB) → un solo chunk
      final file = File('${tempDir.path}/video.mp4');
      await file.writeAsBytes(Uint8List(100));

      final mockClient = MockClient((request) async {
        expect(request.headers['X-Unique-Upload-Id'], 'test-upload-id');
        expect(request.headers['Content-Range'], 'bytes 0-99/100');
        return http.Response(
          jsonEncode({'secure_url': 'https://res.cloudinary.com/test/video.mp4'}),
          200,
        );
      });

      final uploader = ChunkedUploader(client: mockClient);
      final url = await uploader.upload(
        filePath: file.path,
        sigData: {
          'cloudName': 'test-cloud',
          'apiKey': 'key123',
          'timestamp': '1234567890',
          'signature': 'sig123',
          'folder': 'vidalis/test',
          'resourceType': 'video',
        },
        uploadId: 'test-upload-id',
      );

      expect(url, 'https://res.cloudinary.com/test/video.mp4');
    });

    test('resumes from startChunk when completedChunks > 0', () async {
      // Archivo de 13MB → 3 chunks de 6MB + resto. Empezamos desde chunk 1.
      final chunkSize = ChunkedUploader.chunkSizeBytes;
      final fileSize = chunkSize * 2 + 500;
      final file = File('${tempDir.path}/large.mp4');
      await file.writeAsBytes(Uint8List(fileSize));

      final uploadedRanges = <String>[];
      final mockClient = MockClient((request) async {
        uploadedRanges.add(request.headers['Content-Range']!);
        final isLast = request.headers['Content-Range']!.contains('${fileSize - 1}/$fileSize');
        if (isLast) {
          return http.Response(
            jsonEncode({'secure_url': 'https://res.cloudinary.com/test/large.mp4'}),
            200,
          );
        }
        return http.Response(jsonEncode({'done': false}), 200);
      });

      final uploader = ChunkedUploader(client: mockClient);
      await uploader.upload(
        filePath: file.path,
        sigData: {
          'cloudName': 'c',
          'apiKey': 'k',
          'timestamp': '1',
          'signature': 's',
          'folder': 'f',
          'resourceType': 'video',
        },
        uploadId: 'resume-id',
        startChunk: 1, // skip chunk 0
      );

      // Solo chunks 1 y 2, no el 0
      expect(uploadedRanges.length, 2);
      expect(uploadedRanges.first, startsWith('bytes $chunkSize-'));
    });

    test('retries chunk on failure and eventually succeeds', () async {
      final file = File('${tempDir.path}/retry.mp4');
      await file.writeAsBytes(Uint8List(100));

      var attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts < 3) {
          throw const SocketException('Network error');
        }
        return http.Response(
          jsonEncode({'secure_url': 'https://res.cloudinary.com/test/retry.mp4'}),
          200,
        );
      });

      final uploader = ChunkedUploader(client: mockClient);
      final url = await uploader.upload(
        filePath: file.path,
        sigData: {
          'cloudName': 'c',
          'apiKey': 'k',
          'timestamp': '1',
          'signature': 's',
          'folder': 'f',
          'resourceType': 'video',
        },
        uploadId: 'retry-id',
      );

      expect(url, 'https://res.cloudinary.com/test/retry.mp4');
      expect(attempts, 3);
    });

    test('throws after maxRetries exhausted', () async {
      final file = File('${tempDir.path}/fail.mp4');
      await file.writeAsBytes(Uint8List(100));

      final mockClient = MockClient((_) async {
        throw const SocketException('Always fails');
      });

      final uploader = ChunkedUploader(client: mockClient);
      expect(
        () => uploader.upload(
          filePath: file.path,
          sigData: {
            'cloudName': 'c',
            'apiKey': 'k',
            'timestamp': '1',
            'signature': 's',
            'folder': 'f',
            'resourceType': 'video',
          },
          uploadId: 'fail-id',
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
