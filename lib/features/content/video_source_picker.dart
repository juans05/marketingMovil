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
    Navigator.pop(context);
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
                  hintText: 'https://...',
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

// ─── Camera recorder screen ──────────────────────────────────────────────────

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
