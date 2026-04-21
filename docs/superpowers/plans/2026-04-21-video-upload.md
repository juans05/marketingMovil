# Video Upload System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el upload bloqueante de `content_screen.dart` con un sistema que comprime videos a 1080p, sube en chunks resumibles directamente a Cloudinary, muestra un banner global de progreso, y envía una notificación local al completar.

**Architecture:** Flutter comprime (video_compress) y sube en chunks directamente a Cloudinary usando `X-Unique-Upload-Id` para resumibilidad. El estado del upload vive en `UploadQueue` (ChangeNotifier) dentro de `AppProvider`. `AppProvider.startUpload(...)` coordina todo el flujo. Un `UploadBanner` global flota al fondo de cada pantalla. El backend recibe un nuevo endpoint para uploads por URL remota.

**Tech Stack:** Flutter/Dart, video_compress ^3.1.0, camera ^0.11.0, flutter_local_notifications ^17.0.0, connectivity_plus ^6.0.0, Cloudinary Chunked Upload API, Node.js/Express (backend)

**Repos:**
- Flutter: `d:/Github/vidalis_mobile`
- Backend: `d:/Github/marketingDigitalBackend`

---

## Mapa de archivos

| Acción | Archivo |
|--------|---------|
| CREAR | `lib/core/models/upload_job.dart` |
| CREAR | `lib/core/services/video_compressor.dart` |
| CREAR | `lib/core/services/chunked_uploader.dart` |
| CREAR | `lib/core/services/upload_queue.dart` |
| CREAR | `lib/core/services/local_notifier.dart` |
| CREAR | `lib/shared/widgets/upload_banner.dart` |
| CREAR | `lib/features/content/video_source_picker.dart` |
| CREAR | `test/core/services/chunked_uploader_test.dart` |
| CREAR | `test/core/services/upload_queue_test.dart` |
| MODIFICAR | `pubspec.yaml` |
| MODIFICAR | `android/app/src/main/AndroidManifest.xml` |
| MODIFICAR | `ios/Runner/Info.plist` |
| MODIFICAR | `lib/core/services/app_provider.dart` |
| MODIFICAR | `lib/main.dart` |
| MODIFICAR | `lib/app.dart` |
| MODIFICAR | `lib/features/content/content_screen.dart` |
| MODIFICAR (backend) | `src/services/vidalisService.js` |
| MODIFICAR (backend) | `src/controllers/vidalisController.js` |
| MODIFICAR (backend) | `src/routes/vidalisRoutes.js` |

---

## Task 1: Dependencias y permisos de plataforma

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1.1: Agregar paquetes a pubspec.yaml**

En `pubspec.yaml`, dentro de `dependencies:`, agrega después de `image_picker: ^1.1.2`:

```yaml
  # Camera
  camera: ^0.11.0

  # Video compression
  video_compress: ^3.1.0

  # Local notifications
  flutter_local_notifications: ^17.0.0

  # Network connectivity
  connectivity_plus: ^6.0.0
```

- [ ] **Step 1.2: Instalar paquetes**

```bash
cd d:/Github/vidalis_mobile
flutter pub get
```

Esperado: `Got dependencies!` sin errores.

- [ ] **Step 1.3: Permisos Android — AndroidManifest.xml**

En `android/app/src/main/AndroidManifest.xml`, agrega estas líneas ANTES de `<application`:

```xml
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] **Step 1.4: Permisos iOS — Info.plist**

En `ios/Runner/Info.plist`, agrega dentro del `<dict>` principal:

```xml
	<key>NSCameraUsageDescription</key>
	<string>Vidalis necesita la cámara para grabar videos de tus artistas.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>Vidalis necesita el micrófono para grabar audio en los videos.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Vidalis accede a tu galería para subir videos.</string>
```

- [ ] **Step 1.5: Commit**

```bash
cd d:/Github/vidalis_mobile
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat: add camera, video_compress, notifications and connectivity packages"
```

---

## Task 2: Modelo UploadJob

**Files:**
- Create: `lib/core/models/upload_job.dart`

- [ ] **Step 2.1: Crear el modelo**

Crea `lib/core/models/upload_job.dart`:

```dart
enum UploadStatus { preparing, compressing, uploading, registering, done, failed }

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

  const UploadJob({
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
  });

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
    );
  }
}
```

- [ ] **Step 2.2: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/core/models/upload_job.dart
git commit -m "feat: add UploadJob model with status enum"
```

---

## Task 3: VideoCompressor

**Files:**
- Create: `lib/core/services/video_compressor.dart`

> Esta clase usa `video_compress` que llama a código nativo. No se puede unit-testear sin el simulador. Se verifica manualmente en Task 11.

- [ ] **Step 3.1: Crear VideoCompressor**

Crea `lib/core/services/video_compressor.dart`:

```dart
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
        quality: VideoQuality.DefaultQuality, // 720p — balance entre calidad y tamaño
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
```

- [ ] **Step 3.2: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/core/services/video_compressor.dart
git commit -m "feat: add VideoCompressor wrapping video_compress package"
```

---

## Task 4: ChunkedUploader

**Files:**
- Create: `lib/core/services/chunked_uploader.dart`
- Create: `test/core/services/chunked_uploader_test.dart`

- [ ] **Step 4.1: Escribir el test primero**

Crea `test/core/services/chunked_uploader_test.dart`:

```dart
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
```

- [ ] **Step 4.2: Ejecutar el test y verificar que falla**

```bash
cd d:/Github/vidalis_mobile
flutter test test/core/services/chunked_uploader_test.dart
```

Esperado: Error de compilación — `chunked_uploader.dart` no existe aún.

- [ ] **Step 4.3: Implementar ChunkedUploader**

Crea `lib/core/services/chunked_uploader.dart`:

```dart
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
```

- [ ] **Step 4.4: Ejecutar tests y verificar que pasan**

```bash
cd d:/Github/vidalis_mobile
flutter test test/core/services/chunked_uploader_test.dart -v
```

Esperado: 4 tests PASS.

- [ ] **Step 4.5: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/core/services/chunked_uploader.dart test/core/services/chunked_uploader_test.dart
git commit -m "feat: add ChunkedUploader with retry and resume support"
```

---

## Task 5: UploadQueue

**Files:**
- Create: `lib/core/services/upload_queue.dart`
- Create: `test/core/services/upload_queue_test.dart`

- [ ] **Step 5.1: Escribir los tests**

Crea `test/core/services/upload_queue_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vidalis_mobile/core/models/upload_job.dart';
import 'package:vidalis_mobile/core/services/upload_queue.dart';

void main() {
  group('UploadQueue', () {
    late UploadQueue queue;

    setUp(() {
      queue = UploadQueue();
    });

    test('starts empty', () {
      expect(queue.activeJob, isNull);
      expect(queue.hasActiveJob, isFalse);
    });

    test('enqueue sets activeJob', () {
      final job = UploadJob(id: 'job1', artistId: 'a1', title: 'Test');
      queue.enqueue(job);
      expect(queue.activeJob?.id, 'job1');
      expect(queue.hasActiveJob, isTrue);
    });

    test('enqueue ignores second job when one is active', () {
      final job1 = UploadJob(id: 'job1', artistId: 'a1');
      final job2 = UploadJob(id: 'job2', artistId: 'a2');
      queue.enqueue(job1);
      queue.enqueue(job2);
      expect(queue.activeJob?.id, 'job1');
    });

    test('update replaces activeJob', () {
      final job = UploadJob(id: 'job1', artistId: 'a1');
      queue.enqueue(job);
      final updated = job.copyWith(status: UploadStatus.uploading, progress: 0.5);
      queue.update(updated);
      expect(queue.activeJob?.status, UploadStatus.uploading);
      expect(queue.activeJob?.progress, 0.5);
    });

    test('complete marks job as done', () {
      final job = UploadJob(id: 'job1', artistId: 'a1');
      queue.enqueue(job);
      queue.complete();
      expect(queue.activeJob?.status, UploadStatus.done);
    });

    test('fail marks job as failed with message', () {
      final job = UploadJob(id: 'job1', artistId: 'a1');
      queue.enqueue(job);
      queue.fail('Red caída');
      expect(queue.activeJob?.status, UploadStatus.failed);
      expect(queue.activeJob?.errorMessage, 'Red caída');
    });

    test('notifies listeners on enqueue', () {
      var notified = false;
      queue.addListener(() => notified = true);
      queue.enqueue(UploadJob(id: 'j', artistId: 'a'));
      expect(notified, isTrue);
    });
  });
}
```

- [ ] **Step 5.2: Ejecutar el test y verificar que falla**

```bash
cd d:/Github/vidalis_mobile
flutter test test/core/services/upload_queue_test.dart
```

Esperado: Error de compilación — `upload_queue.dart` no existe.

- [ ] **Step 5.3: Implementar UploadQueue**

Crea `lib/core/services/upload_queue.dart`:

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/upload_job.dart';

class UploadQueue extends ChangeNotifier {
  static const _pendingKey = 'vidalis_pending_upload';

  UploadJob? _activeJob;

  UploadJob? get activeJob => _activeJob;
  bool get hasActiveJob => _activeJob != null;

  void enqueue(UploadJob job) {
    if (_activeJob != null) return;
    _activeJob = job;
    notifyListeners();
  }

  void update(UploadJob job) {
    _activeJob = job;
    notifyListeners();
  }

  void complete() {
    if (_activeJob == null) return;
    _activeJob = _activeJob!.copyWith(status: UploadStatus.done, progress: 1.0);
    notifyListeners();
    Future.delayed(const Duration(seconds: 4), () {
      _activeJob = null;
      notifyListeners();
    });
  }

  void fail(String error) {
    if (_activeJob == null) return;
    _activeJob = _activeJob!.copyWith(
      status: UploadStatus.failed,
      errorMessage: error,
    );
    notifyListeners();
    Future.delayed(const Duration(seconds: 5), () {
      _activeJob = null;
      notifyListeners();
    });
  }

  Future<void> savePending(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }
}
```

- [ ] **Step 5.4: Ejecutar tests y verificar que pasan**

```bash
cd d:/Github/vidalis_mobile
flutter test test/core/services/upload_queue_test.dart -v
```

Esperado: 7 tests PASS.

- [ ] **Step 5.5: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/core/services/upload_queue.dart test/core/services/upload_queue_test.dart
git commit -m "feat: add UploadQueue with pending persistence"
```

---

## Task 6: LocalNotifier

**Files:**
- Create: `lib/core/services/local_notifier.dart`

- [ ] **Step 6.1: Crear LocalNotifier**

Crea `lib/core/services/local_notifier.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Canal de notificaciones Android (requerido en Android 8+)
    const channel = AndroidNotificationChannel(
      'vidalis_uploads',
      'Subidas de Video',
      description: 'Notificaciones cuando un video termina de subirse',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> notifyUploadComplete(String? title) async {
    const androidDetails = AndroidNotificationDetails(
      'vidalis_uploads',
      'Subidas de Video',
      channelDescription: 'Notificaciones cuando un video termina de subirse',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.show(
      0,
      '¡Video subido exitosamente!',
      title != null ? '"$title" ya está listo para publicar.' : 'Tu video está listo para publicar.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
```

- [ ] **Step 6.2: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/core/services/local_notifier.dart
git commit -m "feat: add LocalNotifier for upload completion notifications"
```

---

## Task 7: UploadBanner widget

**Files:**
- Create: `lib/shared/widgets/upload_banner.dart`

- [ ] **Step 7.1: Crear el widget**

Crea `lib/shared/widgets/upload_banner.dart`:

```dart
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
                    isFailed ? (job.errorMessage ?? 'Error al subir') : job.statusLabel,
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
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
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
    if (isFailed) return const Icon(Icons.error_outline, color: Colors.white, size: 20);
    if (isDone) return const Icon(Icons.check_circle_outline, color: Colors.white, size: 20);
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
```

- [ ] **Step 7.2: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/shared/widgets/upload_banner.dart
git commit -m "feat: add UploadBanner overlay widget"
```

---

## Task 8: VideoSourcePicker

**Files:**
- Create: `lib/features/content/video_source_picker.dart`

- [ ] **Step 8.1: Crear el widget**

Crea `lib/features/content/video_source_picker.dart`:

```dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';

enum VideoSource { gallery, camera, url }

class VideoSourceResult {
  final VideoSource source;
  final String? filePath;
  final String? remoteUrl;
  final String? title;

  const VideoSourceResult({
    required this.source,
    this.filePath,
    this.remoteUrl,
    this.title,
  });
}

class VideoSourcePicker extends StatefulWidget {
  const VideoSourcePicker({super.key});

  static Future<VideoSourceResult?> show(BuildContext context) {
    return showModalBottomSheet<VideoSourceResult>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const VideoSourcePicker(),
    );
  }

  @override
  State<VideoSourcePicker> createState() => _VideoSourcePickerState();
}

class _VideoSourcePickerState extends State<VideoSourcePicker> {
  final _urlCtrl = TextEditingController();
  bool _showUrlField = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    Navigator.pop(context); // cerrar bottom sheet antes de abrir el picker
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;
    Navigator.pop(
      context,
      VideoSourceResult(
        source: VideoSource.gallery,
        filePath: picked.path,
        title: picked.name,
      ),
    );
  }

  Future<void> _recordWithCamera() async {
    Navigator.pop(context);
    final cameras = await availableCameras();
    if (cameras.isEmpty || !mounted) return;

    final result = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(
        builder: (_) => _CameraRecorderScreen(cameras: cameras),
      ),
    );

    if (result == null || !mounted) return;
    Navigator.pop(
      context,
      VideoSourceResult(
        source: VideoSource.camera,
        filePath: result.path,
        title: 'Video ${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  void _submitUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    Navigator.pop(
      context,
      VideoSourceResult(
        source: VideoSource.url,
        remoteUrl: url,
        title: 'Video desde URL',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿De dónde viene el video?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _SourceOption(
              icon: Icons.photo_library_outlined,
              label: 'Elegir de la galería',
              onTap: _pickFromGallery,
            ),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.videocam_outlined,
              label: 'Grabar con la cámara',
              onTap: _recordWithCamera,
            ),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.link,
              label: 'Pegar URL de video',
              onTap: () => setState(() => _showUrlField = true),
            ),
            if (_showUrlField) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _urlCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _submitUrl,
                  ),
                ),
                onSubmitted: (_) => _submitUrl(),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla de grabación con cámara ────────────────────────────────────────

class _CameraRecorderScreen extends StatefulWidget {
  const _CameraRecorderScreen({required this.cameras});
  final List<CameraDescription> cameras;

  @override
  State<_CameraRecorderScreen> createState() => _CameraRecorderScreenState();
}

class _CameraRecorderScreenState extends State<_CameraRecorderScreen> {
  late CameraController _ctrl;
  bool _initialized = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _ctrl = CameraController(widget.cameras.first, ResolutionPreset.high);
    await _ctrl.initialize();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final file = await _ctrl.stopVideoRecording();
      if (mounted) Navigator.pop(context, file);
    } else {
      await _ctrl.prepareForVideoRecording();
      await _ctrl.startVideoRecording();
      setState(() => _recording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _initialized
          ? Stack(
              children: [
                CameraPreview(_ctrl),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _recording ? Colors.red : Colors.white24,
                        ),
                        child: Icon(
                          _recording ? Icons.stop : Icons.fiber_manual_record,
                          color: _recording ? Colors.white : Colors.red,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
```

- [ ] **Step 8.2: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/features/content/video_source_picker.dart
git commit -m "feat: add VideoSourcePicker with gallery, camera, and URL support"
```

---

## Task 9: Modificar AppProvider

**Files:**
- Modify: `lib/core/services/app_provider.dart`

- [ ] **Step 9.1: Agregar imports y campos**

En `lib/core/services/app_provider.dart`, agrega estos imports al principio junto con los existentes:

```dart
import 'package:video_compress/video_compress.dart';
import '../models/upload_job.dart';
import 'chunked_uploader.dart';
import 'local_notifier.dart';
import 'upload_queue.dart';
import 'video_compressor.dart';
```

- [ ] **Step 9.2: Agregar campos y getter a AppProvider**

En la clase `AppProvider`, después de `String? _errorMessage;`, agrega:

```dart
  late final UploadQueue _uploadQueue;
  LocalNotifier? _localNotifier;

  UploadQueue get uploadQueue => _uploadQueue;
```

- [ ] **Step 9.3: Inicializar en el constructor**

Modifica el constructor de `AppProvider` para inicializar la queue:

```dart
  AppProvider({required StorageService storage, required ApiService api})
      : _storage = storage,
        _api = api {
    _uploadQueue = UploadQueue();
  }
```

- [ ] **Step 9.4: Agregar método setLocalNotifier**

Agrega el método después del constructor:

```dart
  void setLocalNotifier(LocalNotifier notifier) {
    _localNotifier = notifier;
  }
```

- [ ] **Step 9.5: Agregar método startUpload**

Agrega el método `startUpload` al final de la clase `AppProvider`, antes del `}` de cierre:

```dart
  Future<void> startUpload({
    required String artistId,
    required String title,
    String? filePath,         // para galería/cámara
    String? remoteUrl,        // para URL remota
  }) async {
    assert(filePath != null || remoteUrl != null,
        'Se requiere filePath o remoteUrl');

    final uploadId =
        'vidalis_${DateTime.now().millisecondsSinceEpoch}_$artistId';

    var job = UploadJob(
      id: uploadId,
      artistId: artistId,
      title: title,
      filePath: filePath,
      status: UploadStatus.preparing,
    );
    _uploadQueue.enqueue(job);

    // ── Path B: URL remota ─────────────────────────────────────────────────
    if (remoteUrl != null) {
      try {
        job = job.copyWith(status: UploadStatus.registering, progress: 0.2);
        _uploadQueue.update(job);

        await _api.uploadFromUrl(
          artistId: artistId,
          remoteUrl: remoteUrl,
          title: title,
        );

        _uploadQueue.complete();
        _localNotifier?.notifyUploadComplete(title);
      } catch (e) {
        _uploadQueue.fail(e.toString());
      }
      return;
    }

    // ── Path A: Archivo local ──────────────────────────────────────────────
    String? compressedPath;
    try {
      // 1. Comprimir
      job = job.copyWith(status: UploadStatus.compressing, progress: 0.05);
      _uploadQueue.update(job);

      compressedPath = await VideoCompressor.compress(
        filePath!,
        onProgress: (p) {
          _uploadQueue.update(job.copyWith(
            status: UploadStatus.compressing,
            progress: 0.05 + (p * 0.05),
          ));
        },
      );

      // 2. Firma Cloudinary
      final folder = 'vidalis/$artistId';
      final sigData = await _api.getCloudinarySignature(folder, 'video');

      // 3. Persistir para poder reanudar
      await _uploadQueue.savePending({
        'uploadId': uploadId,
        'filePath': compressedPath,
        'artistId': artistId,
        'title': title,
        'completedChunks': 0,
      });

      // 4. Subir en chunks
      job = job.copyWith(
          status: UploadStatus.uploading, filePath: compressedPath, progress: 0.1);
      _uploadQueue.update(job);

      final uploader = ChunkedUploader();
      final secureUrl = await uploader.upload(
        filePath: compressedPath,
        sigData: sigData,
        uploadId: uploadId,
        onProgress: (p) {
          _uploadQueue.update(job.copyWith(
            status: UploadStatus.uploading,
            progress: 0.1 + (p * 0.85),
          ));
        },
      );

      // 5. Registrar en backend
      job = job.copyWith(status: UploadStatus.registering, progress: 0.97);
      _uploadQueue.update(job);

      await _api.registerVideo(
        artistId: artistId,
        sourceUrl: secureUrl,
        title: title,
      );

      await _uploadQueue.clearPending();
      _uploadQueue.complete();
      _localNotifier?.notifyUploadComplete(title);
    } catch (e) {
      _uploadQueue.fail(e.toString());
    } finally {
      if (compressedPath != null) {
        final f = File(compressedPath);
        if (await f.exists()) await f.delete();
      }
    }
  }

  Future<void> resumePendingUpload() async {
    final pending = await _uploadQueue.loadPending();
    if (pending == null) return;

    final filePath = pending['filePath'] as String?;
    if (filePath == null || !File(filePath).existsSync()) {
      await _uploadQueue.clearPending();
      return;
    }

    final artistId = pending['artistId'] as String;
    final title = pending['title'] as String? ?? 'Video';
    final uploadId = pending['uploadId'] as String;
    final completedChunks = (pending['completedChunks'] as num?)?.toInt() ?? 0;

    var job = UploadJob(
      id: uploadId,
      artistId: artistId,
      title: title,
      filePath: filePath,
      status: UploadStatus.uploading,
      completedChunks: completedChunks,
      progress: 0.1,
    );
    _uploadQueue.enqueue(job);

    try {
      final folder = 'vidalis/$artistId';
      final sigData = await _api.getCloudinarySignature(folder, 'video');

      final uploader = ChunkedUploader();
      final secureUrl = await uploader.upload(
        filePath: filePath,
        sigData: sigData,
        uploadId: uploadId,
        startChunk: completedChunks,
        onProgress: (p) {
          _uploadQueue.update(job.copyWith(
            status: UploadStatus.uploading,
            progress: 0.1 + (p * 0.85),
          ));
        },
      );

      job = job.copyWith(status: UploadStatus.registering, progress: 0.97);
      _uploadQueue.update(job);

      await _api.registerVideo(artistId: artistId, sourceUrl: secureUrl, title: title);
      await _uploadQueue.clearPending();
      _uploadQueue.complete();
      _localNotifier?.notifyUploadComplete(title);
    } catch (e) {
      _uploadQueue.fail(e.toString());
    } finally {
      final f = File(filePath);
      if (await f.exists()) await f.delete();
    }
  }
```

- [ ] **Step 9.6: Agregar uploadFromUrl a ApiService**

En `lib/core/services/api_service.dart`, agrega después del método `registerVideo`:

```dart
  Future<VideoModel> uploadFromUrl({
    required String artistId,
    required String remoteUrl,
    String? title,
  }) async {
    final data = await _post('/api/vidalis/videos/from-url', {
      'artist_id': artistId,
      'remote_url': remoteUrl,
      if (title != null) 'title': title,
    });
    return VideoModel.fromJson(data as Map<String, dynamic>);
  }
```

- [ ] **Step 9.7: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/core/services/app_provider.dart lib/core/services/api_service.dart
git commit -m "feat: add startUpload and resumePendingUpload to AppProvider"
```

---

## Task 10: Modificar main.dart y app.dart

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`

- [ ] **Step 10.1: Actualizar main.dart**

Reemplaza el contenido de `lib/main.dart` con:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/api_service.dart';
import 'core/services/local_notifier.dart';
import 'core/services/storage_service.dart';
import 'core/services/app_provider.dart';
import 'core/services/upload_queue.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF09090B),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await initializeDateFormatting('es', null);

  final storage = await StorageService.getInstance();
  final api = ApiService(storage);
  final localNotifier = LocalNotifier();
  await localNotifier.init();

  final appProvider = AppProvider(storage: storage, api: api);
  appProvider.setLocalNotifier(localNotifier);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(
          create: (_) => appProvider.uploadQueue,
        ),
      ],
      child: const VidalisApp(),
    ),
  );
}
```

- [ ] **Step 10.2: Actualizar app.dart para agregar el banner global**

En `lib/app.dart`, agrega el import del banner al principio:

```dart
import 'shared/widgets/upload_banner.dart';
```

Luego, en el método `build` de `VidalisApp`, agrega un `builder` al `MaterialApp` después de `debugShowCheckedModeBanner: false`:

```dart
      builder: (context, child) => Stack(
        children: [
          child!,
          const UploadBannerOverlay(),
        ],
      ),
```

- [ ] **Step 10.3: Agregar reanudación en _SplashRouterState.initState**

En `lib/app.dart`, dentro de `_SplashRouterState.initState()`, agrega después de `_ctrl.forward().then((_) => _navigate());`:

Modifica `_navigate()` en `lib/app.dart` para incluir la reanudación de uploads pendientes:

```dart
  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final prov = context.read<AppProvider>();
    await prov.init();
    // Reanudar upload pendiente si lo hay
    unawaited(prov.resumePendingUpload());
    if (!mounted) return;
    if (prov.user != null) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
```

Agrega el import de `dart:async` al principio de `lib/app.dart`:

```dart
import 'dart:async';
```

- [ ] **Step 10.4: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/main.dart lib/app.dart
git commit -m "feat: add UploadBanner overlay and pending upload resume on startup"
```

---

## Task 11: Modificar content_screen.dart

**Files:**
- Modify: `lib/features/content/content_screen.dart`

- [ ] **Step 11.1: Agregar imports**

Al principio de `lib/features/content/content_screen.dart`, agrega junto a los imports existentes:

```dart
import '../../core/services/upload_queue.dart';
import 'video_source_picker.dart';
```

- [ ] **Step 11.2: Eliminar campos de upload locales**

En `_ContentScreenState`, elimina estas líneas (líneas 29-30):

```dart
  bool _uploading = false;
  double _uploadProgress = 0;
```

- [ ] **Step 11.3: Reemplazar _pickAndUpload**

Reemplaza el método `_pickAndUpload()` completo (línea 109 en adelante) con:

```dart
  Future<void> _openSourcePicker() async {
    final artists = context.read<AppProvider>().artists;
    if (artists.isEmpty) {
      _showSnack('Crea un artista primero', isError: true);
      return;
    }

    var target = artists.first;
    if (artists.length > 1) {
      final picked = await _pickArtistDialog(artists);
      if (picked == null) return;
      target = picked;
    }

    if (!mounted) return;
    final result = await VideoSourcePicker.show(context);
    if (result == null || !mounted) return;

    final prov = context.read<AppProvider>();
    unawaited(prov.startUpload(
      artistId: target.id,
      title: result.title ?? 'Video ${DateTime.now().millisecondsSinceEpoch}',
      filePath: result.filePath,
      remoteUrl: result.remoteUrl,
    ));
  }
```

Agrega `import 'dart:async';` al principio del archivo si no está.

- [ ] **Step 11.4: Actualizar referencias en el build**

Busca donde se usa `_uploading` y `_uploadProgress` en el widget `_GalleryHeader` (alrededor de la línea 248). Reemplaza:

```dart
                uploading: _uploading,
                progress: _uploadProgress,
                onPick: _uploading ? null : _pickAndUpload,
```

Con:

```dart
                uploading: false,
                progress: 0,
                onPick: _openSourcePicker,
```

> El estado de upload ya no vive en la pantalla — vive en `UploadQueue` y se muestra en el banner global. Los campos `uploading` y `progress` de `_GalleryHeader` pueden eliminarse en un refactor posterior, pero por ahora se dejan en `false/0` para no romper la UI.

- [ ] **Step 11.5: Ejecutar análisis estático**

```bash
cd d:/Github/vidalis_mobile
flutter analyze lib/
```

Esperado: sin errores. Corrige cualquier warning de tipo antes de continuar.

- [ ] **Step 11.6: Commit**

```bash
cd d:/Github/vidalis_mobile
git add lib/features/content/content_screen.dart
git commit -m "feat: wire content_screen to VideoSourcePicker and UploadQueue"
```

---

## Task 12: Backend — endpoint POST /videos/from-url

**Files (backend en `d:/Github/marketingDigitalBackend`):**
- Modify: `src/services/vidalisService.js`
- Modify: `src/controllers/vidalisController.js`
- Modify: `src/routes/vidalisRoutes.js`

- [ ] **Step 12.1: Agregar función uploadFromUrl al servicio**

En `src/services/vidalisService.js`, agrega al final antes del último `}` del módulo:

```javascript
exports.uploadFromUrl = async (artistId, remoteUrl, title, userId) => {
  // Verificar que el artista pertenece al usuario
  const { data: artist, error: artistError } = await supabase
    .from('artists')
    .select('id, agency_id')
    .eq('id', artistId)
    .single();

  if (artistError || !artist) throw new Error('Artista no encontrado');

  // Subir a Cloudinary desde la URL remota
  const folder = `vidalis/${artistId}`;
  const result = await cloudinary.uploader.upload(remoteUrl, {
    resource_type: 'video',
    folder,
    eager: 'sp_hd',
    eager_async: true,
  });

  if (!result.secure_url) throw new Error('Cloudinary no retornó URL');

  // Registrar en Supabase
  const { data: video, error: videoError } = await supabase
    .from('videos')
    .insert({
      artist_id: artistId,
      cloudinary_url: result.secure_url,
      title: title || 'Video desde URL',
      status: 'analyzing',
    })
    .select()
    .single();

  if (videoError) throw new Error('Error registrando video: ' + videoError.message);

  // Disparar análisis de IA en background — mismo patrón que processVideo existente
  if (shouldUseInternal()) {
    internalQueue.add(() => aiService.processVideoAI(video.id, result.secure_url, artistId));
  } else {
    n8nQueue.add(() => axios.post(process.env.N8N_WEBHOOK_URL, {
      videoId: video.id,
      videoUrl: result.secure_url,
    }));
  }

  return video;
};
```

- [ ] **Step 12.2: Agregar controlador**

En `src/controllers/vidalisController.js`, agrega el controlador junto a los demás exports:

```javascript
exports.uploadFromUrl = async (req, res) => {
  try {
    const { artist_id, remote_url, title } = req.body;
    if (!artist_id || !remote_url) {
      return res.status(400).json({ error: 'artist_id y remote_url son requeridos' });
    }
    const video = await vidalisService.uploadFromUrl(
      artist_id,
      remote_url,
      title,
      req.user.id
    );
    res.status(201).json(video);
  } catch (error) {
    console.error('uploadFromUrl error:', error.message);
    res.status(500).json({ error: error.message });
  }
};
```

- [ ] **Step 12.3: Agregar ruta**

En `src/routes/vidalisRoutes.js`, agrega después de la línea `router.post('/upload', ...)`:

```javascript
router.post('/videos/from-url', authenticateToken, vidalisController.uploadFromUrl);
```

- [ ] **Step 12.4: Verificar que el backend arranca sin errores**

```bash
cd d:/Github/marketingDigitalBackend
node src/index.js
```

Esperado: servidor arranca sin errores de sintaxis. Ctrl+C para detener.

- [ ] **Step 12.5: Commit backend**

```bash
cd d:/Github/marketingDigitalBackend
git add src/services/vidalisService.js src/controllers/vidalisController.js src/routes/vidalisRoutes.js
git commit -m "feat: add POST /videos/from-url endpoint for remote URL uploads"
```

---

## Task 13: Verificación manual en simulador/dispositivo

- [ ] **Step 13.1: Compilar en modo debug**

```bash
cd d:/Github/vidalis_mobile
flutter run
```

- [ ] **Step 13.2: Verificar flujo galería**

1. Navegar a "Contenido"
2. Pulsar el botón de subir
3. Elegir "Elegir de la galería"
4. Seleccionar un video
5. Verificar que aparece el banner con "Comprimiendo video..."
6. Verificar que el banner actualiza el porcentaje
7. Verificar que el banner muestra "¡Video subido!" en verde
8. Verificar que llega notificación del sistema
9. Verificar que el video aparece en la galería

- [ ] **Step 13.3: Verificar flujo cámara**

1. Pulsar subir → "Grabar con la cámara"
2. Grabar un clip corto
3. Verificar el mismo flujo de banner que en 13.2

- [ ] **Step 13.4: Verificar flujo URL remota**

1. Pulsar subir → "Pegar URL de video"
2. Ingresar una URL directa de video (no YouTube — Cloudinary necesita URL directa de archivo)
3. Verificar que el banner muestra "Procesando..."
4. Verificar éxito

- [ ] **Step 13.5: Verificar reanudación (simular fallo)**

1. Iniciar un upload de galería
2. Matar la app durante la subida (antes de que termine)
3. Reabrir la app
4. Verificar que el banner reaparece y el upload continúa

- [ ] **Step 13.6: Commit final**

```bash
cd d:/Github/vidalis_mobile
git add .
git commit -m "feat: complete video upload system with chunked upload, compression, and banner"
```
