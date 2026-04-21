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
