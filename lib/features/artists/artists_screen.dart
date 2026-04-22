import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/artist_model.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/vidalis_button.dart';
import '../../shared/widgets/vidalis_input.dart';
import '../../shared/widgets/vidalis_dropdown.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadArtists();
    });
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateArtistSheet(),
    );
  }

  Future<void> _deleteArtist(ArtistModel artist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Eliminar artista',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '¿Eliminar a ${artist.name}? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      final prov = context.read<AppProvider>();
      final ok = await prov.deleteArtist(artist.id);
      if (ok) {
        HapticFeedback.lightImpact();
      } else if (mounted && prov.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(prov.errorMessage!),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final artists = prov.artists;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Artista'),
      ),
      body: artists.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline,
                      color: AppColors.textMuted, size: 64),
                  const SizedBox(height: 12),
                  const Text('Sin artistas aún',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Crea tu primer artista para comenzar',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  VidalisButton(
                    label: 'Crear Artista',
                    onPressed: _showCreateSheet,
                    fullWidth: false,
                    icon: Icons.person_add_outlined,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: artists.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final artist = artists[i];
                return _ArtistCard(
                  artist: artist,
                  isActive: prov.activeArtist?.id == artist.id,
                  onSelect: () => prov.setActiveArtist(artist),
                  onDelete: () => _deleteArtist(artist),
                );
              },
            ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.artist,
    required this.isActive,
    required this.onSelect,
    required this.onDelete,
  });
  final ArtistModel artist;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isActive
          ? AppColors.primaryGlow(radius: 14)
          : AppColors.glassCard(radius: 14),
      child: Column(
        children: [
          // Header
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                artist.name[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            ),
            title: Text(artist.name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            subtitle: artist.genre != null
                ? Text(artist.genre!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Activo',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  TextButton(
                    onPressed: onSelect,
                    child: const Text('Seleccionar',
                        style: TextStyle(
                            color: AppColors.primary, fontSize: 12)),
                  ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 18),
                ),
              ],
            ),
          ),
          // Platforms
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _SocialSection(artist: artist),
          ),
        ],
      ),
    );
  }
}

class _SocialSection extends StatefulWidget {
  const _SocialSection({required this.artist});
  final ArtistModel artist;

  @override
  State<_SocialSection> createState() => _SocialSectionState();
}

class _SocialSectionState extends State<_SocialSection> {
  Map<String, bool> _status = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus({bool refresh = false}) async {
    setState(() => _loading = true);
    try {
      final prov = context.read<AppProvider>();
      final status = await prov.api.getSocialStatus(
        widget.artist.id,
        refresh: refresh,
      );
      if (mounted) setState(() => _status = status);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    final prov = context.read<AppProvider>();
    try {
      final url = await prov.api.getConnectSocialUrl(widget.artist.id);
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Refrescar estado desde el backend al volver del navegador
        if (mounted) await _loadStatus(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 24,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            SocialPlatformChip(
                platform: 'tiktok',
                connected: _status['tiktok'] ?? widget.artist.hasTiktok),
            SocialPlatformChip(
                platform: 'instagram',
                connected:
                    _status['instagram'] ?? widget.artist.hasInstagram),
            SocialPlatformChip(
                platform: 'youtube',
                connected: _status['youtube'] ?? widget.artist.hasYoutube),
          ],
        ),
        const SizedBox(height: 10),
        VidalisButton(
          label: 'Conectar Redes',
          onPressed: _connect,
          variant: VidalisButtonVariant.outlined,
          icon: Icons.link,
        ),
      ],
    );
  }
}

class _CreateArtistSheet extends StatefulWidget {
  const _CreateArtistSheet();

  @override
  State<_CreateArtistSheet> createState() => _CreateArtistSheetState();
}

class _CreateArtistSheetState extends State<_CreateArtistSheet> {
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
      if (ok) {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      } else {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(prov.errorMessage ?? 'Error al crear artista'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nuevo Artista',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Esta información permite a la IA generar copy y hashtags personalizados',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            VidalisInput(
              label: 'Nombre *',
              hint: 'Nombre del artista o marca',
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
            const SizedBox(height: 24),
            VidalisButton(
              label: 'Crear Artista',
              onPressed: _saving ? null : _submit,
              isLoading: _saving,
              icon: Icons.person_add_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
