import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/artist_model.dart';
import '../models/video_model.dart';
import '../models/upload_job.dart';
import 'api_service.dart';
import 'local_notifier.dart';
import 'storage_service.dart';
import 'upload_queue.dart';
import 'upload_worker.dart';
import 'video_compressor.dart';

enum AppStatus { idle, loading, error }

class AppProvider extends ChangeNotifier {
  AppProvider({required StorageService storage, required ApiService api})
      : _storage = storage,
        _api = api {
    _uploadQueue = UploadQueue();
    _uploadQueue.addListener(notifyListeners);
  }

  void setLocalNotifier(LocalNotifier notifier) {
    _localNotifier = notifier;
  }

  final StorageService _storage;
  final ApiService _api;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  UserModel? _user;
  ArtistModel? _activeArtist;
  List<ArtistModel> _artists = [];
  StatsModel? _stats;
  AppStatus _status = AppStatus.idle;
  String? _errorMessage;

  late final UploadQueue _uploadQueue;
  LocalNotifier? _localNotifier;

  UploadQueue get uploadQueue => _uploadQueue;

  UserModel? get user => _user;
  ArtistModel? get activeArtist => _activeArtist;
  List<ArtistModel> get artists => _artists;
  StatsModel? get stats => _stats;
  AppStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AppStatus.loading;
  bool get isAgency => _user?.isAgency ?? false;
  ApiService get api => _api;
  StorageService get storage => _storage;

  // ── Upload queue convenience getters ──────────────────────────────────────
  bool get isUploading => _uploadQueue.hasActiveJob;
  double get uploadProgress => _uploadQueue.activeJob?.progress ?? 0.0;
  String? get currentUploadTitle => _uploadQueue.activeJob?.title;

  void _setLoading() {
    _status = AppStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AppStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void _setIdle() {
    _status = AppStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> init() async {
    _user = _storage.getUser();
    if (_user == null) return;
    // Siempre cargar artistas desde el backend para tener datos completos.
    // Para agencias: carga todos sus artistas.
    // Para usuarios individuales: carga su artista propio (mismo endpoint, filtra por user id).
    await loadArtists();
  }

  Future<bool> login(String email, String password) async {
    _setLoading();
    try {
      final user = await _api.login(email, password);
      _user = user;
      await _storage.saveUser(user);
      _api.refreshToken();
      await init();
      _setIdle();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Error de conexión. Verifica tu internet.');
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _setLoading();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setIdle();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        _setError('No se pudo obtener el token de Google.');
        return false;
      }

      final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
      final user = await _api.loginWithGoogle(idToken, platform);
      
      _user = user;
      await _storage.saveUser(user);
      _api.refreshToken();
      await init();
      _setIdle();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _setError('Error Google: $e');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String birthDate) async {
    _setLoading();
    try {
      final user = await _api.registerUser(name, email, password, birthDate);
      _user = user;
      await _storage.saveUser(user);
      _api.refreshToken();
      _setIdle();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Error de conexión. Verifica tu internet.');
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearUser();
    _user = null;
    _activeArtist = null;
    _artists = [];
    _stats = null;
    _setIdle();
  }

  Future<void> loadArtists() async {
    if (_user == null) return;
    try {
      _artists = await _api.getArtists(_user!.id);
      if (_artists.isNotEmpty) {
        // Mantener el artista activo si sigue en la lista, sino usar el primero
        final stillActive = _activeArtist != null &&
            _artists.any((a) => a.id == _activeArtist!.id);
        if (!stillActive) {
          _activeArtist = _artists.first;
        } else {
          // Refrescar datos del artista activo con los datos completos del backend
          _activeArtist = _artists.firstWhere((a) => a.id == _activeArtist!.id);
        }
      } else {
        _activeArtist = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('loadArtists error: $e');
      // No limpiar artistas existentes si ya había datos
    }
  }

  void setActiveArtist(ArtistModel artist) {
    _activeArtist = artist;
    _stats = null;
    notifyListeners();
  }

  Future<bool> createArtist(
    String name, {
    String? genre,
    String? aiGenre,
    String? aiAudience,
    String? aiTone,
  }) async {
    if (_user == null) return false;
    _setLoading();
    try {
      final artist = await _api.createArtist(
        _user!.id,
        name,
        genre: genre,
        aiGenre: aiGenre,
        aiAudience: aiAudience,
        aiTone: aiTone,
      );
      _artists = [..._artists, artist];
      _activeArtist ??= artist;
      _setIdle();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('No se pudo crear el artista.');
      return false;
    }
  }

  Future<bool> deleteArtist(String artistId) async {
    _setLoading();
    try {
      await _api.deleteArtist(artistId);
      _artists = _artists.where((a) => a.id != artistId).toList();
      if (_activeArtist?.id == artistId) {
        _activeArtist = _artists.isNotEmpty ? _artists.first : null;
      }
      _setIdle();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('No se pudo eliminar el artista.');
      return false;
    }
  }

  Future<StatsModel?> loadStats() async {
    if (_user == null) return null;
    try {
      _stats = await _api.getStats(_user!.id, artistId: _activeArtist?.id);
      notifyListeners();
      return _stats;
    } catch (_) {
      return null;
    }
  }

  Future<bool> syncStats() async {
    if (_activeArtist == null) return false;
    _setLoading();
    try {
      await _api.syncSocialStats(_activeArtist!.id);
      await loadStats();
      _setIdle();
      return true;
    } catch (e) {
      _setError('Error al sincronizar: $e');
      return false;
    }
  }

  Future<bool> updateArtistStyle(Map<String, dynamic> dna) async {
    if (_activeArtist == null) return false;
    _setLoading();
    try {
      await _api.updateArtistStyle(num.parse(_activeArtist!.id), dna);
      // Actualizar el artista activo localmente si es necesario
      await loadArtists(); 
      _setIdle();
      return true;
    } catch (e) {
      _setError('Error al actualizar estilo: $e');
      return false;
    }
  }

  Future<void> runDeepAudit({bool allowFullAudit = false}) async {
    if (_activeArtist == null) return;
    _setLoading();
    try {
      await _api.runDeepAudit(_activeArtist!.id, allowFullAudit);
      await loadStats();
    } catch (e) {
      rethrow;
    } finally {
      _setIdle();
    }
  }

  void clearError() {
    _errorMessage = null;
    _status = AppStatus.idle;
    notifyListeners();
  }

  Future<void> startUpload({
    required String artistId,
    required String title,
    String? filePath,
    String? remoteUrl,
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
    _localNotifier?.notifyUploadStarted(title);

    // ── Path B: URL remota (isolate) ─────────────────────────────────────────
    if (remoteUrl != null) {
      try {
        job = job.copyWith(status: UploadStatus.registering, progress: 0.2);
        _uploadQueue.update(job);

        final receivePort = ReceivePort();
        await Isolate.spawn(_remoteUploadIsolate, {
          'sendPort': receivePort.sendPort,
          'baseUrl': _storage.apiUrl,
          'authToken': _user?.token ?? '',
          'artistId': artistId,
          'remoteUrl': remoteUrl,
          'title': title,
        });

        await for (final msg in receivePort) {
          final message = UploadMessage.fromJson(msg as Map<String, dynamic>);
          if (message.type == 'progress') {
            job = job.copyWith(
              status: _statusFromLabel(message.status),
              progress: message.progress ?? 0.0,
            );
            _uploadQueue.update(job);
          } else if (message.type == 'log') {
            debugPrint('[UPLOAD] ${message.log}');
            job = job.withLog(message.log ?? '');
            _uploadQueue.update(job);
          } else if (message.type == 'done') {
            _uploadQueue.complete();
            _localNotifier?.notifyUploadComplete(title);
            receivePort.close();
            break;
          } else if (message.type == 'error') {
            _uploadQueue.fail(message.error ?? 'Error desconocido');
            _localNotifier?.notifyUploadFailed(title, message.error ?? '');
            receivePort.close();
            break;
          }
        }
      } catch (e) {
        _uploadQueue.fail(e.toString());
        _localNotifier?.notifyUploadFailed(title, e.toString());
      }
      return;
    }

    // ── Path A: Archivo local ──────────────────────────────────────────────
    String? finalPath;
    try {
      final file = File(filePath!);
      final fileSize = await file.length();
      final needsCompression = fileSize > 10 * 1024 * 1024; // 10MB

      // Compresión solo si >10MB (corre en main isolate - video_compress usa platform channels)
      if (needsCompression) {
        job = job.copyWith(status: UploadStatus.compressing, progress: 0.05);
        _uploadQueue.update(job);

        final compressedPath = await VideoCompressor.compress(
          filePath,
          onProgress: (p) {
            _uploadQueue.update(job.copyWith(
              status: UploadStatus.compressing,
              progress: 0.05 + (p * 0.05),
            ));
          },
        );
        finalPath = compressedPath;
      } else {
        // Skip compresión - archivo ya es pequeño
        finalPath = filePath;
        job = job.copyWith(status: UploadStatus.uploading, progress: 0.1);
        _uploadQueue.update(job);
      }

      // Obtener signature (rapido)
      final folder = 'vidalis/$artistId';
      final sigData = await _api.getCloudinarySignature(folder, 'video');

      await _uploadQueue.savePending({
        'uploadId': uploadId,
        'filePath': finalPath,
        'artistId': artistId,
        'title': title,
        'completedChunks': 0,
      });

      // Subida + registro en isolate de fondo
      final receivePort = ReceivePort();
      await Isolate.spawn(_fileUploadIsolate, {
        'sendPort': receivePort.sendPort,
        'params': {
          'filePath': finalPath,
          'artistId': artistId,
          'title': title,
          'baseUrl': _storage.apiUrl,
          'authToken': _user?.token ?? '',
          'sigData': sigData,
          'uploadId': uploadId,
        },
      });

      job = job.copyWith(status: UploadStatus.uploading, progress: 0.1);
      _uploadQueue.update(job);

      await for (final msg in receivePort) {
        final message = UploadMessage.fromJson(msg as Map<String, dynamic>);
        if (message.type == 'progress') {
          _uploadQueue.update(job.copyWith(
            status: _statusFromLabel(message.status),
            progress: message.progress ?? 0.0,
          ));
        } else if (message.type == 'done') {
          // Descontar sparks localmente
          if (_user != null) {
            _user = _user!.copyWith(sparksBalance: _user!.sparksBalance - 10);
            await _storage.saveUser(_user!);
          }

          await _uploadQueue.clearPending();
          _uploadQueue.complete();
          _localNotifier?.notifyUploadComplete(title);
          receivePort.close();
          break;
        } else if (message.type == 'error') {
          _uploadQueue.fail(message.error ?? 'Error desconocido');
          _localNotifier?.notifyUploadFailed(title, message.error ?? '');
          receivePort.close();
          break;
        }
      }
    } catch (e) {
      _uploadQueue.fail(e.toString());
      _localNotifier?.notifyUploadFailed(title, e.toString());
    } finally {
      // Limpiar archivo comprimido solo si fue comprimido y subio exitosamente
      if (finalPath != null && finalPath != filePath && _uploadQueue.activeJob?.status == UploadStatus.done) {
        final f = File(finalPath);
        if (await f.exists()) await f.delete();
      }
    }
  }

  UploadStatus _statusFromLabel(String? label) {
    switch (label) {
      case 'compressing': return UploadStatus.compressing;
      case 'registering': return UploadStatus.registering;
      case 'uploading': return UploadStatus.uploading;
      default: return UploadStatus.uploading;
    }
  }

  // Wrapper para Isolate.spawn (debe ser static o top-level function)
  static void _fileUploadIsolate(Map<String, dynamic> params) {
    uploadWorker(params);
  }

  static void _remoteUploadIsolate(Map<String, dynamic> params) {
    uploadFromUrlWorker(params);
  }

  Future<void> resumePendingUpload({bool showDialog = true}) async {
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
    _localNotifier?.notifyUploadStarted(title);

    try {
      final folder = 'vidalis/$artistId';
      final sigData = await _api.getCloudinarySignature(folder, 'video');

      final receivePort = ReceivePort();
      await Isolate.spawn(_fileUploadIsolate, {
        'sendPort': receivePort.sendPort,
        'params': {
          'filePath': filePath,
          'artistId': artistId,
          'title': title,
          'baseUrl': _storage.apiUrl,
          'authToken': _user?.token ?? '',
          'sigData': sigData,
          'uploadId': uploadId,
        },
      });

      await for (final msg in receivePort) {
        final message = UploadMessage.fromJson(msg as Map<String, dynamic>);
        if (message.type == 'progress') {
          _uploadQueue.update(job.copyWith(
            status: _statusFromLabel(message.status),
            progress: message.progress ?? 0.0,
          ));
        } else if (message.type == 'done') {
          if (_user != null) {
            _user = _user!.copyWith(sparksBalance: _user!.sparksBalance - 10);
            await _storage.saveUser(_user!);
          }

          await _uploadQueue.clearPending();
          _uploadQueue.complete();
          _localNotifier?.notifyUploadComplete(title);
          receivePort.close();
          break;
        } else if (message.type == 'error') {
          _uploadQueue.fail(message.error ?? 'Error desconocido');
          _localNotifier?.notifyUploadFailed(title, message.error ?? '');
          receivePort.close();
          break;
        }
      }
    } catch (e) {
      _uploadQueue.fail(e.toString());
      _localNotifier?.notifyUploadFailed(title, e.toString());
    } finally {
      if (_uploadQueue.activeJob?.status == UploadStatus.done) {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      }
    }
  }

  Future<void> checkPendingUpload(BuildContext? context) async {
    final pending = await _uploadQueue.loadPending();
    if (pending == null) return;

    final filePath = pending['filePath'] as String?;
    if (filePath == null || !File(filePath).existsSync()) {
      await _uploadQueue.clearPending();
      return;
    }

    if (context == null || context.mounted == false) return;

    final title = pending['title'] as String? ?? 'Video';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Subida pendiente',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Tienes una subida pendiente: "$title". ¿Deseas reanudarla?',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5C7),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reanudar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await resumePendingUpload();
    } else {
      await _uploadQueue.clearPending();
    }
  }

  Future<bool> purchaseSparks(int amount) async {
    if (_user == null) return false;
    _setLoading();
    try {
      final newBalance = await _api.purchaseSparks(_user!.id, amount);
      _user = _user!.copyWith(sparksBalance: newBalance);
      await _storage.saveUser(_user!);
      _setIdle();
      return true;
    } catch (e) {
      _setError('Error al recargar Sparks: $e');
      return false;
    }
  }

  Future<bool> redeemCoupon(String code) async {
    if (_user == null) return false;
    _setLoading();
    try {
      final res = await _api.redeemCoupon(_user!.id, code);
      // Conversión segura de num a int
      final newBalance = (res['newBalance'] as num).toInt();
      _user = _user!.copyWith(sparksBalance: newBalance);
      await _storage.saveUser(_user!);
      _setIdle();
      return true;
    } catch (e) {
      _setError('Error: $e');
      return false;
    }
  }
}
