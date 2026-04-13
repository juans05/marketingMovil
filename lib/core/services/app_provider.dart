import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/artist_model.dart';
import '../models/video_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

enum AppStatus { idle, loading, error }

class AppProvider extends ChangeNotifier {
  AppProvider({required StorageService storage, required ApiService api})
      : _storage = storage,
        _api = api;

  final StorageService _storage;
  final ApiService _api;

  UserModel? _user;
  ArtistModel? _activeArtist;
  List<ArtistModel> _artists = [];
  StatsModel? _stats;
  AppStatus _status = AppStatus.idle;
  String? _errorMessage;

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

    if (_user!.isAgency) {
      await loadArtists();
    } else if (_user!.artistId != null) {
      _activeArtist = ArtistModel(
        id: _user!.artistId!,
        name: _user!.name,
        agencyId: _user!.id,
      );
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading();
    try {
      final user = await _api.login(email, password);
      _user = user;
      await _storage.saveUser(user);
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

  Future<bool> register(String name, String email, String password) async {
    _setLoading();
    try {
      final user = await _api.registerAgency(name, email, password);
      _user = user;
      await _storage.saveUser(user);
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
      if (_artists.isNotEmpty && _activeArtist == null) {
        _activeArtist = _artists.first;
      }
      notifyListeners();
    } catch (_) {
      // Silently fail — artists may simply be empty
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
      _stats = await _api.getStats(_user!.id);
      notifyListeners();
      return _stats;
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    _status = AppStatus.idle;
    notifyListeners();
  }
}
