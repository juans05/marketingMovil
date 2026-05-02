import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/growth_model.dart';
import '../../../core/models/video_model.dart';
import '../../../core/services/app_provider.dart';

class ABTestingScreen extends StatefulWidget {
  const ABTestingScreen({super.key, this.preselectedVideoId});
  final String? preselectedVideoId;

  @override
  State<ABTestingScreen> createState() => _ABTestingScreenState();
}

class _ABTestingScreenState extends State<ABTestingScreen> {
  List<VideoModel> _videos = [];
  VideoModel? _selected;
  ABTestData? _testData;
  bool _loadingVideos = true;
  bool _loadingTest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final prov = context.read<AppProvider>();
    final artistId = prov.activeArtist?.id;
    if (artistId == null) {
      setState(() => _loadingVideos = false);
      return;
    }
    try {
      final videos = await prov.api.getGallery(artistId);
      final ready = videos.where((v) => v.isReady || v.isPublished).toList();
      if (mounted) {
        setState(() => _videos = ready);
        if (widget.preselectedVideoId != null) {
          final pre = ready.where((v) => v.id == widget.preselectedVideoId).firstOrNull;
          if (pre != null) {
            _selected = pre;
            _loadTest(pre.id);
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingVideos = false);
    }
  }

  Future<void> _loadTest(String videoId) async {
    setState(() { _loadingTest = true; _error = null; });
    final prov = context.read<AppProvider>();
    try {
      final data = await prov.api.getABResult(videoId);
      if (mounted) setState(() => _testData = data);
    } catch (_) {
      // No test yet, generate one
      try {
        final data = await prov.api.generateABVariants(videoId);
        if (mounted) setState(() => _testData = data);
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text('🧪 A/B Testing', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loadingVideos
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _VideoSelector(
                  videos: _videos,
                  selected: _selected,
                  onSelected: (v) {
                    setState(() { _selected = v; _testData = null; });
                    _loadTest(v.id);
                  },
                ),
                const SizedBox(height: 20),
                if (_selected == null)
                  const _EmptyHint(message: 'Selecciona un video para ver o generar el A/B test')
                else if (_loadingTest)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ))
                else if (_error != null)
                  _ErrorCard(error: _error!, onRetry: () => _loadTest(_selected!.id))
                else if (_testData != null)
                  _TestResult(data: _testData!),
              ],
            ),
    );
  }
}

class _VideoSelector extends StatelessWidget {
  const _VideoSelector({required this.videos, this.selected, required this.onSelected});
  final List<VideoModel> videos;
  final VideoModel? selected;
  final void Function(VideoModel) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppColors.glassCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECCIONA UN VIDEO', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          if (videos.isEmpty)
            const Text('No hay videos listos aún', style: TextStyle(color: AppColors.textMuted))
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<VideoModel>(
                isExpanded: true,
                value: selected,
                dropdownColor: AppColors.bgCard,
                hint: const Text('Elige un video', style: TextStyle(color: AppColors.textMuted)),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                items: videos.map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(v.title ?? 'Video sin título', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) { if (v != null) onSelected(v); },
              ),
            ),
        ],
      ),
    );
  }
}

class _TestResult extends StatelessWidget {
  const _TestResult({required this.data});
  final ABTestData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('VARIANTES', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const Spacer(),
            if (data.isComplete)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('TEST COMPLETADO', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w700)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('EN PROGRESO · 24H', style: TextStyle(color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...data.variants.asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          final isWinner = data.isComplete && v.isWinner;
          return _VariantCard(
            label: String.fromCharCode(65 + i),
            variant: v,
            isWinner: isWinner,
          );
        }),
        if (!data.isComplete) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppColors.glassCard(radius: 12),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El A/B test se resolverá automáticamente en 24h. Vidalis seleccionará el caption ganador.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.label, required this.variant, required this.isWinner});
  final String label;
  final ABVariant variant;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWinner ? AppColors.success.withValues(alpha: 0.1) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWinner ? AppColors.success : AppColors.border,
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  gradient: isWinner ? AppColors.primaryGradient : const LinearGradient(colors: [AppColors.bgInput, AppColors.bgInput]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(label, style: TextStyle(color: isWinner ? Colors.black : AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              if (isWinner) ...[
                const Text('🏆 GANADOR', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
              const Spacer(),
              if (variant.likes > 0 || variant.comments > 0)
                Row(
                  children: [
                    const Icon(Icons.favorite, color: AppColors.accent, size: 14),
                    const SizedBox(width: 3),
                    Text('${variant.likes}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chat_bubble_outline, color: AppColors.info, size: 14),
                    const SizedBox(width: 3),
                    Text('${variant.comments}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: variant.caption));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Caption copiado'), backgroundColor: AppColors.success),
                  );
                },
                child: const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(variant.caption, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppColors.glassCard(radius: 14),
      child: Column(
        children: [
          const Text('🧪', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(radius: 14),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 36),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Reintentar', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }
}
