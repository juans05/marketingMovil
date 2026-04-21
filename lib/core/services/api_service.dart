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

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final user = _storage.getUser();
    if (user?.token != null) {
      headers['Authorization'] = 'Bearer ${user!.token}';
    }
    return headers;
  }

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

  Future<UserModel> loginWithGoogle(String idToken, String platform) async {
    final data = await _post(ApiConstants.loginGoogle, {
      'idToken': idToken,
      'platform': platform,
    });
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<String> refineCopy(String text, String? artistId) async {
    final data = await _post(ApiConstants.refineCopy, {
      'text': text,
      'artist_id': artistId,
    });
    return (data as Map<String, dynamic>)['refined'] as String;
  }

  Future<UserModel> registerUser(String name, String email, String password, String birthDate) async {
    final data = await _post(ApiConstants.login, {
      'name': name,
      'email': email,
      'password': password,
      'birth_date': birthDate,
      'account_type': 'individual',
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
      'genre': ?genre,
      'ai_genre': ?aiGenre,
      'ai_audience': ?aiAudience,
      'ai_tone': ?aiTone,
    });
    return ArtistModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteArtist(String artistId) async {
    await _delete(ApiConstants.deleteArtist(artistId));
  }

  Future<void> updateArtistStyle(num artistId, Map<String, dynamic> creativeDna) async {
    await _patch('/api/vidalis/artists/$artistId/style', {
      'creative_dna': creativeDna
    });
  }

  Future<Map<String, dynamic>> runDeepAudit(String artistId, bool allowFullAudit) async {
    final data = await _post('/api/vidalis/artists/$artistId/audit', {
      'allow_full_audit': allowFullAudit
    });
    return data as Map<String, dynamic>;
  }

  // ─── Content ─────────────────────────────────────────────────────────────
  Future<List<VideoModel>> getGallery(String artistId, {int? limit, int? page}) async {
    String path = ApiConstants.gallery(artistId);
    final params = <String>[];
    if (limit != null) params.add('limit=$limit');
    if (page != null) params.add('page=$page');
    if (params.isNotEmpty) path += '?${params.join('&')}';

    final data = await _get(path);
    final list = data as List;
    return list
        .map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getCloudinarySignature(String folder, String resourceType) async {
    final res = await _get('${ApiConstants.cloudinarySignature}?folder=$folder&resourceType=$resourceType');
    return res as Map<String, dynamic>;
  }

  Future<String> uploadToCloudinary({
    required File file,
    required Map<String, dynamic> sigData,
    void Function(double progress)? onProgress,
  }) async {
    final cloudName = sigData['cloudName'];
    final resourceType = sigData['resourceType'] ?? 'video';
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

    final request = http.MultipartRequest('POST', uri);
    request.fields['api_key'] = sigData['apiKey'].toString();
    request.fields['timestamp'] = sigData['timestamp'].toString();
    request.fields['signature'] = sigData['signature'].toString();
    request.fields['folder'] = sigData['folder'].toString();
    request.fields['access_mode'] = 'public';
    if (sigData['eager'] != null) {
      request.fields['eager'] = sigData['eager'].toString();
    }

    final fileStream = http.ByteStream(file.openRead());
    final fileLength = await file.length();
    final multipartFile = http.MultipartFile(
      'file',
      fileStream,
      fileLength,
      filename: file.path.split('/').last,
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send().timeout(const Duration(minutes: 10));

    if (onProgress != null) {
      int sent = 0;
      streamedResponse.stream.listen((chunk) {
        // Nota: El progreso del stream local no es el progreso de subida de red real 
        // pero da una idea de que el proceso está vivo.
        sent += chunk.length;
        onProgress(sent / fileLength);
      });
    }

    final res = await http.Response.fromStream(streamedResponse);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body);
      return body['secure_url'].toString();
    } else {
      throw ApiException('Fallo al subir a Cloudinary: ${res.body}', statusCode: res.statusCode);
    }
  }

  Future<VideoModel> registerVideo({
    required String artistId,
    required String sourceUrl,
    String? title,
    List<String>? platforms,
  }) async {
    final data = await _post(ApiConstants.upload, {
      'videoData': {
        'artist_id': artistId,
        'source_url': sourceUrl,
        'status': 'analyzing',
        'title': ?title,
        if (platforms != null) 'platforms': platforms.join(','),
      }
    });
    return VideoModel.fromJson(data as Map<String, dynamic>);
  }

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

  Future<VideoModel> updateVideo(
      String videoId, Map<String, dynamic> updates) async {
    final data = await _patch(ApiConstants.video(videoId), updates);
    return VideoModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> publishNow(String videoId, List<String> platforms, {String postType = 'reel'}) async {
    await _post(ApiConstants.publishNow(videoId), {'platforms': platforms, 'postType': postType});
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

  Future<void> syncSocialStats(String artistId) async {
    await _post(ApiConstants.socialSync(artistId), {});
  }
}
