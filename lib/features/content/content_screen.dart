import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/artist_model.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/vidalis_button.dart';
import '../../shared/widgets/vidalis_input.dart';
import '../../shared/widgets/vidalis_dropdown.dart';
import 'video_detail_screen.dart';
import 'video_source_picker.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  // videos con su artista asociado para mostrar etiqueta
  List<({VideoModel video, ArtistModel? artist})> _entries = [];
  bool _loading = true;
  String? _error;

  // Artista filtro seleccionado (null = todos)
  String? _filterArtistId;

  // Control para no recargar si los artistas/activeArtist no cambiaron
  String? _lastLoadedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.watch<AppProvider>();
    final artists = prov.artists;
    final active = prov.activeArtist;

    // Construir una clave que represente el estado actual
    final key = '${active?.id}_${artists.map((a) => a.id).join(',')}';

    if (key != _lastLoadedKey && artists.isNotEmpty) {
      _lastLoadedKey = key;
      _load(prov);
    } else if (artists.isEmpty && !prov.isLoading) {
      // Sin artistas creados aún
      setState(() {
        _loading = false;
        _entries = [];
        _error = null;
      });
    }
  }

  Future<void> _load([AppProvider? injected]) async {
    final prov = injected ?? context.read<AppProvider>();
    final artists = prov.artists;

    if (artists.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _entries = [];
          _error = null;
        });
      }
      return;
    }

    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      // Determinar qué artistas cargar
      final toLoad = _filterArtistId != null
          ? artists.where((a) => a.id == _filterArtistId).toList()
          : (prov.activeArtist != null ? [prov.activeArtist!] : artists);

      final allEntries = <({VideoModel video, ArtistModel? artist})>[];

      for (final artist in toLoad) {
        try {
          final videos = await prov.api.getGallery(artist.id);
          for (final v in videos) {
            allEntries.add((video: v, artist: toLoad.length > 1 ? artist : null));
          }
        } catch (_) {
          // Si falla un artista, continuar con los demás
        }
      }

      // Ordenar por fecha de creación desc
      allEntries.sort((a, b) =>
          b.video.createdAt.compareTo(a.video.createdAt));

      if (mounted) setState(() => _entries = allEntries);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSourcePicker() async {
    final prov = context.read<AppProvider>();
    final artists = prov.artists;
    if (artists.isEmpty) {
      _showSnack('Crea un artista primero', isError: true);
      return;
    }

    var target = artists.first;
    if (artists.length > 1) {
      final picked = await _pickArtistDialog(artists);
      if (picked == null) return;
      target = picked;
    }

    if (!mounted) return;
    final result = await VideoSourcePicker.show(context);
    if (result == null || !mounted) return;

    unawaited(prov.startUpload(
      artistId: target.id,
      title: result.title ?? 'Video ${DateTime.now().millisecondsSinceEpoch}',
      filePath: result.filePath,
      remoteUrl: result.remoteUrl,
    ));
  }

  Future<ArtistModel?> _pickArtistDialog(List<ArtistModel> artists) {
    return showDialog<ArtistModel>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('¿Para qué artista?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: artists
              .map((a) => ListTile(
                    title: Text(a.name,
                        style:
                            const TextStyle(color: AppColors.textPrimary)),
                    subtitle: a.genre != null
                        ? Text(a.genre!,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12))
                        : null,
                    onTap: () => Navigator.pop(context, a),
                  ))
              .toList(),
        ),
      ),
    );
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
    final prov = context.watch<AppProvider>();
    final artists = prov.artists;
    final showFilter = artists.length > 1;

    return RefreshIndicator(
      onRefresh: () => _load(),
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: CustomScrollView(
        slivers: [
          // Upload card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _UploadCard(
                uploading: false,
                progress: 0,
                onPick: _openSourcePicker,
              ),
            ),
          ),

          // Filtro de artistas (solo agencias con múltiples artistas)
          if (showFilter)
            SliverToBoxAdapter(
              child: _ArtistFilterBar(
                artists: artists,
                selectedId: _filterArtistId,
                onSelect: (id) {
                  setState(() {
                    _filterArtistId = id;
                    _lastLoadedKey = null; // forzar recarga
                  });
                  _load();
                },
              ),
            ),

          // Contenido
          if (_loading)
            const SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: _SkeletonGallery(),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            )
          else if (artists.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _CreateFirstArtistPanel(),
            )
          else if (_entries.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_library_outlined,
                        color: AppColors.textMuted, size: 64),
                    SizedBox(height: 12),
                    Text('Sin videos aún',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Sube tu primer video para comenzar',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
                children: _entries
                    .map((e) => _VideoCard(
                          video: e.video,
                          artistName: e.artist?.name,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VideoDetailScreen(video: e.video),
                            ),
                          ).then((_) => _load()),
                        ))
                    .toList(),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Panel crear primer artista ──────────────────────────────────────────────

class _CreateFirstArtistPanel extends StatefulWidget {
  const _CreateFirstArtistPanel();

  @override
  State<_CreateFirstArtistPanel> createState() =>
      _CreateFirstArtistPanelState();
}

class _CreateFirstArtistPanelState extends State<_CreateFirstArtistPanel> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  String? _selectedGenre;
  String? _selectedTone;
  bool _saving = false;

  static const _genreOptions = [
    'Reggaeton / Urbano', 'Pop / Comercial', 'Hip-Hop / Trap',
    'Electronic / EDM', 'Rock / Alternative', 'Indie / Singer-Songwriter',
    'R&B / Soul', 'Jazz / Blues', 'Classical / Cinematic',
    'Folk / Country', 'Podcast / Talk Show', 'Gaming / Tutorial',
    'Lifestyle / Vlogging',
  ];

  static const _toneOptions = [
    'Energético / High-Energy', 'Inspiracional / Motivating',
    'Profesional / Authoritative', 'Divertido / Humorístico',
    'Lujoso / Premium', 'Auténtico / Raw', 'Educativo / Informative',
    'Provocativo / Edgy', 'Minimalista / Clean', 'Emocional / Deep',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _audienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final prov = context.read<AppProvider>();
    final ok = await prov.createArtist(
      _nameCtrl.text.trim(),
      genre: _selectedGenre,
      aiGenre: _selectedGenre,
      aiAudience: _audienceCtrl.text.trim().isEmpty
          ? null
          : _audienceCtrl.text.trim(),
      aiTone: _selectedTone,
    );
    if (mounted) {
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(prov.errorMessage ?? 'Error al crear artista'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.auto_awesome,
                      color: AppColors.primary, size: 36),
                  SizedBox(height: 10),
                  Text(
                    'Configura tu primer artista',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Esta información permite a la IA generar copy, hashtags y viral score personalizados para cada video',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Campos
            VidalisInput(
              label: 'Nombre del artista o marca *',
              hint: 'Ej: Bad Bunny, Nike, GymBro',
              controller: _nameCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),
            VidalisDropdown(
              label: 'Género / Nicho',
              hint: 'Selecciona un género',
              items: _genreOptions,
              value: _selectedGenre,
              onChanged: (v) => setState(() => _selectedGenre = v),
            ),
            const SizedBox(height: 14),
            VidalisInput(
              label: 'Público objetivo',
              hint: 'Ej: Jóvenes 18-25 fanáticos del trap latino',
              controller: _audienceCtrl,
            ),
            const SizedBox(height: 14),
            VidalisDropdown(
              label: 'Tono de comunicación',
              hint: 'Selecciona un tono',
              items: _toneOptions,
              value: _selectedTone,
              onChanged: (v) => setState(() => _selectedTone = v),
            ),
            const SizedBox(height: 28),
            VidalisButton(
              label: 'Crear artista y continuar',
              onPressed: _saving ? null : _submit,
              isLoading: _saving,
              icon: Icons.rocket_launch_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filtro de artistas ───────────────────────────────────────────────────────

class _ArtistFilterBar extends StatelessWidget {
  const _ArtistFilterBar({
    required this.artists,
    required this.selectedId,
    required this.onSelect,
  });
  final List<ArtistModel> artists;
  final String? selectedId;
  final void Function(String? id) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          // Chip "Todos"
          _FilterChip(
            label: 'Todos',
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          ...artists.map((a) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: a.name,
                  selected: selectedId == a.id,
                  onTap: () => onSelect(a.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Upload Card ──────────────────────────────────────────────────────────────

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.uploading,
    required this.progress,
    required this.onPick,
  });

  final bool uploading;
  final double progress;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (uploading) ...[
            const Text('Subiendo video...',
                style:
                    TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ] else ...[
            const Icon(Icons.cloud_upload_outlined,
                color: AppColors.primary, size: 36),
            const SizedBox(height: 8),
            const Text('Subir Video',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Selecciona un video de tu galería',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            VidalisButton(
              label: 'Seleccionar Video',
              onPressed: onPick,
              fullWidth: false,
              icon: Icons.video_library_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Video Card ───────────────────────────────────────────────────────────────

class _VideoCard extends StatefulWidget {
  const _VideoCard({
    required this.video,
    required this.onTap,
    this.artistName,
  });
  final VideoModel video;
  final String? artistName;
  final VoidCallback onTap;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = widget.video.isProcessing;
    final video = widget.video;
    final artistName = widget.artistName;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          decoration: AppColors.glassCard(radius: 16),
          child: Stack(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: video.thumbnailUrl != null
                  ? Image.network(
                      video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) =>
                          const _ThumbnailFallback(),
                    )
                  : const _ThumbnailFallback(),
            ),
            // Processing overlay
            if (isProcessing)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                      SizedBox(height: 8),
                      Text('IA procesando',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            // Bottom info
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Etiqueta de artista (solo en vista "Todos")
                    if (artistName != null)
                      Text(
                        artistName,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      video.title ?? 'Sin título',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatusChip(status: video.status),
                        if (video.viralScore != null)
                          ViralScoreBadge(score: video.viralScore!, size: 36),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),   // AnimatedBuilder
    );   // GestureDetector
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgCard,
      child: const Center(
        child: Icon(Icons.video_file, color: AppColors.textMuted, size: 40),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'published' => ('Publicado', AppColors.success),
      'scheduled' => ('Programado', AppColors.warning),
      'ready' => ('Listo', AppColors.info),
      _ => ('Procesando', AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}
class _SkeletonGallery extends StatelessWidget {
  const _SkeletonGallery();

  @override
  Widget build(BuildContext context) {
    return SliverGrid.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75,
      children: List.generate(
        4,
        (index) => Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 10,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 40,
                      height: 10,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
