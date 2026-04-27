import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/vidalis_button.dart';
import '../../shared/widgets/vidalis_input.dart';
import '../analytics/video_analytics_screen.dart';

class VideoDetailScreen extends StatefulWidget {
  const VideoDetailScreen({super.key, required this.video});
  final VideoModel video;

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late VideoModel _video;

  // Editor controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _copyCtrl;
  late TextEditingController _hashtagCtrl;
  bool _saving = false;
  bool _refining = false;
  bool _publishing = false;
  bool _retrying = false;
  bool _deleting = false;

  // Publish
  final List<String> _platforms = [];
  String _postType = 'reel';

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _tab = TabController(length: 3, vsync: this);
    _titleCtrl = TextEditingController(text: _video.title ?? '');
    _copyCtrl = TextEditingController(text: _video.aiCopy ?? '');
    _hashtagCtrl = TextEditingController(
        text: _video.hashtags.map((h) => '#$h').join(' '));
    _platforms.addAll(_video.platforms);
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _copyCtrl.dispose();
    _hashtagCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prov = context.read<AppProvider>();
    try {
      final hashtags = _hashtagCtrl.text
          .split(RegExp(r'[\s,]+'))
          .map((h) => h.replaceAll('#', '').trim())
          .where((h) => h.isNotEmpty)
          .toList();

      final updated = await prov.api.updateVideo(_video.id, {
        'title': _titleCtrl.text.trim(),
        'ai_copy_short': _copyCtrl.text.trim(),
        'hashtags': hashtags,
      });
      setState(() => _video = updated);
      if (mounted) {
        HapticFeedback.selectionClick();
        _showSnack('Cambios guardados');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refine() async {
    if (_copyCtrl.text.trim().isEmpty) {
      _showSnack('Escribe algo primero para humanizarlo', isError: true);
      return;
    }
    setState(() => _refining = true);
    final prov = context.read<AppProvider>();
    try {
      final refined = await prov.api.refineCopy(_copyCtrl.text.trim(), _video.artistId);
      setState(() => _copyCtrl.text = refined);
      if (mounted) _showSnack('¡Texto humanizado con éxito!');
    } catch (e) {
      if (mounted) _showSnack('Error al humanizar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _refining = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Eliminar video', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('¿Seguro que quieres eliminar este video? Esta acción no se puede deshacer.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    final prov = context.read<AppProvider>();
    try {
      await prov.api.deleteVideo(_video.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Error al eliminar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final prov = context.read<AppProvider>();
    try {
      await prov.api.retryVideo(_video.id);
      if (mounted) _showSnack('Análisis reiniciado. Espera unos minutos.');
    } catch (e) {
      if (mounted) _showSnack('Error al reintentar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _publishNow() async {
    if (_platforms.isEmpty) {
      _showSnack('Selecciona al menos una plataforma', isError: true);
      return;
    }
    setState(() => _publishing = true);
    final prov = context.read<AppProvider>();
    try {
      await prov.api.publishNow(_video.id, _platforms, postType: _postType);
      if (mounted) {
        HapticFeedback.mediumImpact();
        _showSnack('¡Publicación en camino! Puede demorar hasta 10 minutos.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: Text(
          _video.title ?? 'Detalle de Video',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_video.isProcessing || _video.isError)
            _retrying
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                    tooltip: 'Reintentar análisis',
                    onPressed: _retry,
                  ),
          _deleting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  tooltip: 'Eliminar video',
                  onPressed: _delete,
                ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Info IA'),
            Tab(text: 'Editor'),
            Tab(text: 'Publicar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _InfoTab(video: _video),
          _EditorTab(
            titleCtrl: _titleCtrl,
            copyCtrl: _copyCtrl,
            hashtagCtrl: _hashtagCtrl,
            onSave: _save,
            saving: _saving,
            onRefine: _refine,
            refining: _refining,
          ),
          _PublishTab(
            plan: prov.user?.plan ?? 'Mini',
            activePlatforms: prov.activeArtist?.activePlatforms ?? [],
            platforms: _platforms,
            postType: _postType,
            onTogglePlatform: (p) {
              setState(() {
                if (_platforms.contains(p)) {
                  _platforms.remove(p);
                } else {
                  _platforms.add(p);
                }
              });
            },
            onChangePostType: (t) => setState(() => _postType = t),
            onPublishNow: _publishing ? null : _publishNow,
            publishing: _publishing,
          ),
        ],
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.video});
  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Thumbnail + score
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: video.thumbnailUrl != null
                ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ThumbnailFallback())
                : const _ThumbnailFallback(),
          ),
        ),
        const SizedBox(height: 16),
        if (video.isProcessing || video.isError) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: video.isError
                  ? AppColors.danger.withValues(alpha: 0.08)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: video.isError
                    ? AppColors.danger.withValues(alpha: 0.3)
                    : AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                video.isError
                    ? const Icon(Icons.error_outline, color: AppColors.danger, size: 22)
                    : const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.isError ? 'Error en el análisis IA' : 'Analizando video con IA',
                        style: TextStyle(
                          color: video.isError ? AppColors.danger : AppColors.textPrimary,
                          fontWeight: FontWeight.w600, fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.isError
                            ? 'El análisis falló. Toca el ícono 🔄 arriba para reintentar.'
                            : 'Esto puede tardar unos minutos. Si pasa más de 10 min, toca 🔄 arriba.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (video.viralScore != null) ...[
          Row(
            children: [
              ViralScoreBadge(score: video.viralScore!, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Viral Score',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      video.viralScore!.toStringAsFixed(1),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _scoreLabel(video.viralScore!),
                      style: TextStyle(
                          color: AppColors.viralScoreColor(video.viralScore!),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (video.status == 'published' || video.ayrsharePostId != null) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoAnalyticsScreen(video: video),
                  ),
                );
              },
              icon: const Icon(Icons.show_chart, size: 18),
              label: const Text('Ver Estadísticas Reales'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
        if (video.hookSuggestion != null) ...[
          _Section(
            title: 'Hook Sugerido',
            icon: Icons.lightbulb_outline,
            child: Text(video.hookSuggestion!,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 16),
        ],
        if (video.aiCopy != null) ...[
          _Section(
            title: 'Copy IA',
            icon: Icons.auto_awesome,
            child: Text(video.aiCopy!,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 16),
        ],
        if (video.hashtags.isNotEmpty) ...[
          _Section(
            title: 'Hashtags',
            icon: Icons.tag,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: video.hashtags
                  .map((h) => Chip(
                        label: Text('#$h',
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 12)),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  String _scoreLabel(double score) {
    if (score >= 8) return 'Viral potencial alto';
    if (score >= 6) return 'Buen potencial';
    if (score >= 4) return 'Potencial moderado';
    return 'Mejorar contenido';
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppColors.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 16),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgCard,
      child: const Center(
          child: Icon(Icons.video_file, color: AppColors.textMuted, size: 48)),
    );
  }
}

class _EditorTab extends StatelessWidget {
  const _EditorTab({
    required this.titleCtrl,
    required this.copyCtrl,
    required this.hashtagCtrl,
    required this.onSave,
    required this.saving,
    required this.onRefine,
    required this.refining,
  });
  final TextEditingController titleCtrl;
  final TextEditingController copyCtrl;
  final TextEditingController hashtagCtrl;
  final VoidCallback onSave;
  final bool saving;
  final VoidCallback onRefine;
  final bool refining;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        VidalisInput(
          label: 'Título',
          hint: 'Título del video',
          controller: titleCtrl,
        ),
        const SizedBox(height: 16),
        VidalisInput(
          label: 'Copy',
          hint: 'Descripción para redes sociales...',
          controller: copyCtrl,
          maxLines: 5,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: refining ? null : onRefine,
            icon: refining 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
              : const Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
            label: Text(
              refining ? 'Humanizando...' : 'Humanizar Texto',
              style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        VidalisInput(
          label: 'Hashtags',
          hint: '#musica #viral #trending',
          controller: hashtagCtrl,
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        VidalisButton(
          label: 'Guardar Cambios',
          onPressed: saving ? null : onSave,
          isLoading: saving,
          icon: Icons.save_outlined,
        ),
      ],
    );
  }
}

class _PublishTab extends StatelessWidget {
  const _PublishTab({
    required this.plan,
    required this.activePlatforms,
    required this.platforms,
    required this.postType,
    required this.onTogglePlatform,
    required this.onChangePostType,
    required this.onPublishNow,
    required this.publishing,
  });
  final String plan;
  final List<String> activePlatforms;
  final List<String> platforms;
  final String postType;
  final void Function(String) onTogglePlatform;
  final void Function(String) onChangePostType;
  final VoidCallback? onPublishNow;
  final bool publishing;

  @override
  Widget build(BuildContext context) {
    final allPlatformItems = [
      ('instagram', 'Instagram', Icons.camera_alt,        Color(0xFFE1306C)),
      ('tiktok',    'TikTok',    Icons.music_note,       Color(0xFF00F2EA)),
      ('facebook',  'Facebook',  Icons.facebook_outlined,    Color(0xFF1877F2)),
      ('youtube',   'YouTube',   Icons.play_circle_fill, Color(0xFFFF0000)),
      ('linkedin',  'LinkedIn',  Icons.link,             Color(0xFF0077B5)),
    ];

    // Mapa de límites por plan (Sincronizado con Backend)
    final planLimits = {
      'Mini':        ['instagram', 'tiktok'],
      'Artista':     ['instagram', 'tiktok', 'facebook'],
      'Estrella':    ['instagram', 'tiktok', 'facebook', 'youtube', 'linkedin'],
      'Agencia Pro': ['instagram', 'tiktok', 'facebook', 'youtube', 'linkedin'],
    };

    final allowed = planLimits[plan] ?? planLimits['Mini']!;
    final platformItems = allPlatformItems.where((p) {
      return allowed.contains(p.$1) && activePlatforms.contains(p.$1);
    }).toList();

    const postTypes = [
      ('reel',  '🎬 Reels'),
      ('story', '📱 Stories'),
      ('feed',  '📰 Feed'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tipo de contenido
        const Text(
          'Tipo de Contenido',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: postTypes.map((item) {
            final (id, label) = item;
            final selected = postType == id;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChangePostType(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Plataformas
        const Text(
          'Plataformas',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...platformItems.map((item) {
          final (id, label, icon, color) = item;
          final selected = platforms.contains(id);
          return GestureDetector(
            onTap: () => onTogglePlatform(id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.1) : AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color.withValues(alpha: 0.5) : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: selected ? color : AppColors.textMuted),
                  const SizedBox(width: 12),
                  Text(label,
                      style: TextStyle(
                          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle, color: color, size: 20),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),

        // Info card about limits
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.accent, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Límites diarios por red (TikTok: 15, IG: 50). Evita duplicados en menos de 48h para prevenir bloqueos de spam.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        VidalisButton(
          label: 'Lanzar Ahora',
          onPressed: onPublishNow,
          isLoading: publishing,
          icon: Icons.rocket_launch_outlined,
        ),
      ],
    );
  }
}
