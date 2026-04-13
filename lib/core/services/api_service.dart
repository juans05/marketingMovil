import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/user_model.dart';
import '../models/artist_model.dart';
import '../models/video_model.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  ApiService(this._storage) : _baseUrl = _storage.apiUrl;

  final StorageService _storage;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String url) {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    _storage.saveApiUrl(_baseUrl);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> _get(String path) async {
    final res = await http.get(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final res = await http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  Future<dynamic> _delete(String path) async {
    final res = await http
        .delete(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Error ${res.statusCode}';
    try {
      final body = jsonDecode(res.body);
      message = body['error'] ?? body['message'] ?? message;
    } catch (_) {}
    throw ApiException(message, statusCode: res.statusCode);
  }

  // ─── Auth ────────────────────────────────────────────────────────────────
  Future<UserModel> login(String email, String password) async {
    final data = await _post(ApiConstants.login, {
      'email': email,
      'password': password,
    });
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<UserModel> registerAgency(String name, String email, String password) async {
    final data = await _post(ApiConstants.createAgency, {
      'name': name,
      'email': email,
      'password': password,
    });
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  // ─── Artists ─────────────────────────────────────────────────────────────
  Future<List<ArtistModel>> getArtists(String agencyId) async {
    final data = await _get(ApiConstants.artists(agencyId));
    final list = data as List;
    return list
        .map((e) => ArtistModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ArtistModel> createArtist(
    String agencyId,
    String name, {
    String? genre,
    String? aiGenre,
    String? aiAudience,
    String? aiTone,
  }) async {
    final data = await _post(ApiConstants.createArtist, {
      'agency_id': agencyId,
      'name': name,
      if (genre != null) 'genre': genre,
      if (aiGenre != null) 'ai_genre': aiGenre,
      if (aiAudience != null) 'ai_audience': aiAudience,
      if (aiTone != null) 'ai_tone': aiTone,
    });
    return ArtistModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteArtist(String artistId) async {
    await _delete(ApiConstants.deleteArtist(artistId));
  }

  // ─── Content ─────────────────────────────────────────────────────────────
  Future<List<VideoModel>> getGallery(String artistId) async {
    final data = await _get(ApiConstants.gallery(artistId));
    final list = data as List;
    return list
        .map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VideoModel> uploadVideo({
    required File videoFile,
    required String artistId,
    String? title,
    List<String>? platforms,
    void Function(double progress)? onProgress,
  }) async {
    final request = http.MultipartRequest('POST', _uri(ApiConstants.upload));
    request.fields['artist_id'] = artistId;
    if (title != null) request.fields['title'] = title;
    if (platforms != null) request.fields['platforms'] = platforms.join(',');

    final fileStream = http.ByteStream(videoFile.openRead());
    final fileLength = await videoFile.length();
    final multipartFile = http.MultipartFile(
      'video',
      fileStream,
      fileLength,
      filename: videoFile.path.split('/').last,
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send()
        .timeout(const Duration(minutes: 5));

    if (onProgress != null) {
      int received = 0;
      streamedResponse.stream.listen((chunk) {
        received += chunk.length;
        onProgress(received / fileLength);
      });
    }

    final res = await http.Response.fromStream(streamedResponse);
    final data = _handle(res);
    return VideoModel.fromJson(data as Map<String, dynamic>);
  }

  Future<VideoModel> updateVideo(
      String videoId, Map<String, dynamic> updates) async {
    final data = await _patch(ApiConstants.video(videoId), updates);
    return VideoModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> publishNow(String videoId, List<String> platforms) async {
    await _post(ApiConstants.publishNow(videoId), {'platforms': platforms});
  }

  Future<void> scheduleVideo(
      String videoId, DateTime scheduledAt, List<String> platforms) async {
    await _patch(ApiConstants.video(videoId), {
      'scheduled_at': scheduledAt.toIso8601String(),
      'platforms': platforms,
      'status': 'scheduled',
    });
  }

  // ─── Stats ───────────────────────────────────────────────────────────────
  Future<StatsModel> getStats(String agencyId) async {
    final data = await _get(ApiConstants.stats(agencyId));
    return StatsModel.fromJson(data as Map<String, dynamic>);
  }

  Future<AnalyticsModel> getAnalytics(String videoId) async {
    final data = await _get(ApiConstants.analytics(videoId));
    return AnalyticsModel.fromJson(data as Map<String, dynamic>);
  }

  // ─── Social ──────────────────────────────────────────────────────────────
  Future<Map<String, bool>> getSocialStatus(String artistId,
      {bool refresh = false}) async {
    final path = '${ApiConstants.socialStatus(artistId)}'
        '${refresh ? '?refresh=true' : ''}';
    final data = await _get(path);
    final map = data as Map<String, dynamic>;
    // Backend returns { "platforms": ["instagram", "tiktok"] }
    final platforms = (map['platforms'] as List?)?.cast<String>() ?? [];
    return {
      'tiktok': platforms.contains('tiktok'),
      'instagram': platforms.contains('instagram'),
      'youtube': platforms.contains('youtube'),
      'facebook': platforms.contains('facebook'),
    };
  }

  Future<String> getConnectSocialUrl(String artistId) async {
    final data = await _get(ApiConstants.connectSocial(artistId));
    final map = data as Map<String, dynamic>;
    return map['url']?.toString() ?? '$_baseUrl${ApiConstants.connectSocial(artistId)}';
  }
}
