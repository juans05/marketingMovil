import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/upload_job.dart';

class UploadQueue extends ChangeNotifier {
  static const _pendingKey = 'vidalis_pending_upload';

  UploadJob? _activeJob;
  final _progressNotifier = ValueNotifier<double>(0.0);

  UploadJob? get activeJob => _activeJob;
  bool get hasActiveJob => _activeJob != null;
  ValueListenable<double> get progressListenable => _progressNotifier;

  void enqueue(UploadJob job) {
    if (_activeJob != null) return;
    _activeJob = job;
    _progressNotifier.value = job.progress;
    notifyListeners();
  }

  void update(UploadJob job) {
    _activeJob = job;
    _progressNotifier.value = job.progress;
    notifyListeners();
  }

  void complete() {
    if (_activeJob == null) return;
    _activeJob = _activeJob!.copyWith(status: UploadStatus.done, progress: 1.0);
    HapticFeedback.mediumImpact();
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
    HapticFeedback.heavyImpact();
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
