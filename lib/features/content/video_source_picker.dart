import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
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
      isScrollControlled: true,   // permite que el sheet suba con el teclado
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        // empuja el contenido por encima del teclado
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const VideoSourcePicker(),
      ),
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
    // Abrimos el picker ANTES de cerrar el sheet para mantener el contexto
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
    if (picked == null || !mounted) return;
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
    // Abrimos la cámara sin cerrar el bottom sheet primero
    // Usamos Navigator.push desde el contexto actual
    final result = await Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _CameraRecorderScreen(),
      ),
    );

    if (result == null || !mounted) return;

    // Ahora sí cerramos el bottom sheet con el resultado
    Navigator.pop(
      context,
      VideoSourceResult(
        source: VideoSource.camera,
        filePath: result.path,
        title: 'Vidalis_${DateTime.now().millisecondsSinceEpoch}',
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

// ─── Source Option Widget ─────────────────────────────────────────────────────

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

// ─── Camera Recorder Screen ───────────────────────────────────────────────────

class _CameraRecorderScreen extends StatefulWidget {
  const _CameraRecorderScreen();

  @override
  State<_CameraRecorderScreen> createState() => _CameraRecorderScreenState();
}

class _CameraRecorderScreenState extends State<_CameraRecorderScreen> {
  CameraController? _ctrl;
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;           // 0 = trasera, 1 = frontal
  bool _initialized = false;
  bool _recording = false;
  String? _errorMsg;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMsg = 'No se encontró ninguna cámara disponible.');
        return;
      }
      await _startCamera(_camIndex);
    } catch (e) {
      setState(() => _errorMsg = 'Error inicializando cámara: $e');
    }
  }

  Future<void> _startCamera(int index) async {
    final oldCtrl = _ctrl;
    if (oldCtrl != null) {
      await oldCtrl.dispose();
      _ctrl = null;
    }

    final ctrl = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _initialized = true;
        _errorMsg = null;
      });

      // Boost exposure a bit if it's too dark
      try {
        await ctrl.setExposureOffset(0.5); // Small boost by default
      } catch (_) {}
    } catch (e) {
      await ctrl.dispose();
      setState(() => _errorMsg = 'Error de cámara: ${e.toString()}');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _recording) return;
    _camIndex = (_camIndex + 1) % _cameras.length;
    setState(() => _initialized = false);
    await _startCamera(_camIndex);
  }

  Future<void> _toggleRecording() async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;

    if (_recording) {
      // ── PARAR y mostrar preview ──
      final file = await _ctrl!.stopVideoRecording();
      setState(() => _recording = false);
      if (!mounted) return;

      // Navegar a la pantalla de preview
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => _VideoPreviewScreen(file: file)),
      );

      if (confirmed == true && mounted) {
        Navigator.pop(context, file);   // Devuelve el archivo a VideoSourcePicker
      }
    } else {
      // ── EMPEZAR ──
      try {
        await _ctrl!.prepareForVideoRecording();
        await _ctrl!.startVideoRecording();
        setState(() => _recording = true);
        _trackElapsed();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al grabar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleTapFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;

    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;
    final point = Offset(x, y);

    try {
      await _ctrl!.setFocusPoint(point);
      await _ctrl!.setExposurePoint(point);
    } catch (e) {
      debugPrint("Error setting focus point: $e");
    }
  }

  void _trackElapsed() {
    _elapsed = Duration.zero;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_recording) return false;
      setState(() => _elapsed += const Duration(seconds: 1));
      return true;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(_errorMsg!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized || _ctrl == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview de cámara centrado con tap-to-focus
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onTapDown: (details) => _handleTapFocus(details, constraints),
              child: Center(child: CameraPreview(_ctrl!)),
            ),
          ),

          // Botón cerrar (arriba izquierda)
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: _recording ? null : () => Navigator.pop(context, null),
            ),
          ),

          // Cambiar cámara (arriba derecha)
          if (_cameras.length > 1)
            Positioned(
              top: 50,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                onPressed: _flipCamera,
              ),
            ),

          // Temporizador mientras graba
          if (_recording)
            Positioned(
              top: 58,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, color: Colors.white, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Botón de grabación (abajo centro)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _recording
                        ? Colors.red
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.fiber_manual_record,
                    color: _recording ? Colors.white : Colors.red,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),

          // Texto de ayuda
          if (!_recording)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Toca para grabar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Video Preview Screen (confirmar antes de guardar) ────────────────────────

class _VideoPreviewScreen extends StatefulWidget {
  const _VideoPreviewScreen({required this.file});
  final XFile file;

  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
  late VideoPlayerController _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.file.path))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _player.play();
          _player.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            Center(child: AspectRatio(aspectRatio: _player.value.aspectRatio, child: VideoPlayer(_player)))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Título
          const Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Vista previa',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Botones abajo
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Descartar', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check, color: Colors.black),
                    label: const Text('Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


