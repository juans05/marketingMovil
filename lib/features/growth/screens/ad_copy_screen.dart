import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/growth_model.dart';
import '../../../core/models/video_model.dart';
import '../../../core/services/app_provider.dart';

class AdCopyScreen extends StatefulWidget {
  const AdCopyScreen({super.key});

  @override
  State<AdCopyScreen> createState() => _AdCopyScreenState();
}

class _AdCopyScreenState extends State<AdCopyScreen> {
  List<VideoModel> _videos = [];
  VideoModel? _selected;
  List<AdCopyData> _copies = [];
  bool _loadingVideos = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final prov = context.read<AppProvider>();
    final artistId = prov.activeArtist?.id;
    if (artistId == null) { setState(() => _loadingVideos = false); return; }
    try {
      final videos = await prov.api.getGallery(artistId);
      if (mounted) setState(() => _videos = videos.where((v) => v.isReady || v.isPublished).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingVideos = false);
    }
  }

  Future<void> _generate() async {
    if (_selected == null) return;
    setState(() { _generating = true; _error = null; _copies = []; });
    try {
      final copies = await context.read<AppProvider>().api.generateAdCopy(_selected!.id);
      if (mounted) setState(() => _copies = copies);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text('📣 Copy para Anuncios', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loadingVideos
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                _VideoSelector(
                  videos: _videos,
                  selected: _selected,
                  onSelected: (v) => setState(() { _selected = v; _copies = []; _error = null; }),
                ),
                const SizedBox(height: 16),
                if (_selected != null) ...[
                  GestureDetector(
                    onTap: _generating ? null : _generate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: _generating ? AppColors.glassCard(radius: 12) : AppColors.primaryGlow(radius: 12),
                      child: Center(
                        child: _generating
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                  SizedBox(width: 10),
                                  Text('Generando copy...', style: TextStyle(color: AppColors.textSecondary)),
                                ],
                              )
                            : const Text('✨ GENERAR AD COPY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                if (_copies.isNotEmpty) ...[
                  const Text('COPIES GENERADOS', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  ..._copies.map((c) => _AdCopyCard(copy: c)),
                ],
                if (_copies.isEmpty && !_generating && _selected == null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppColors.glassCard(radius: 14),
                    child: const Column(
                      children: [
                        Text('📣', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text('Selecciona un video y genera\nel copy listo para publicar en anuncios', style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
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

class _AdCopyCard extends StatelessWidget {
  const _AdCopyCard({required this.copy});
  final AdCopyData copy;

  static const _platformColors = {
    'meta': Color(0xFF1877F2),
    'tiktok': Color(0xFF00F2EA),
  };

  static const _platformLabels = {
    'meta': 'Meta Ads',
    'tiktok': 'TikTok Ads',
  };

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado al portapapeles'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _platformColors[copy.platform] ?? AppColors.primary;
    final label = _platformLabels[copy.platform] ?? copy.platform;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _copy(context, '${copy.headline}\n\n${copy.primaryText}\n\n${copy.cta}'),
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 16),
                    const SizedBox(width: 4),
                    const Text('Copiar todo', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FieldRow(label: 'HEADLINE', value: copy.headline, onCopy: () => _copy(context, copy.headline)),
          const SizedBox(height: 10),
          _FieldRow(label: 'TEXTO PRINCIPAL', value: copy.primaryText, onCopy: () => _copy(context, copy.primaryText)),
          const SizedBox(height: 10),
          _FieldRow(label: 'CTA', value: copy.cta, onCopy: () => _copy(context, copy.cta), highlight: true),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value, required this.onCopy, this.highlight = false});
  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const Spacer(),
            GestureDetector(onTap: onCopy, child: const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 14)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: highlight ? AppColors.primary.withValues(alpha: 0.1) : AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: highlight ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
          ),
          child: Text(value, style: TextStyle(color: highlight ? AppColors.primary : AppColors.textPrimary, fontSize: 13, height: 1.4, fontWeight: highlight ? FontWeight.w600 : FontWeight.w400)),
        ),
      ],
    );
  }
}
