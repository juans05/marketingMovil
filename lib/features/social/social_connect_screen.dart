import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/vidalis_button.dart';

class SocialConnectScreen extends StatefulWidget {
  const SocialConnectScreen({super.key});

  @override
  State<SocialConnectScreen> createState() => _SocialConnectScreenState();
}

class _SocialConnectScreenState extends State<SocialConnectScreen> {
  Map<String, bool> _status = {};
  bool _loading = true;
  bool _connecting = false;
  bool _verifying = false;
  bool _portalOpened = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus({bool refresh = false}) async {
    final prov = context.read<AppProvider>();
    final artist = prov.activeArtist;
    if (artist == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final status = await prov.api.getSocialStatus(artist.id, refresh: refresh);
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    final prov = context.read<AppProvider>();
    final artist = prov.activeArtist;
    if (artist == null) return;

    setState(() { _connecting = true; _error = null; });
    try {
      final url = await prov.api.getConnectSocialUrl(artist.id);
      final uri = Uri.parse(url);
      
      // Intentamos abrir directamente, ya que canLaunchUrl a veces falla falsamente en Android 11+
      final launched = await launchUrl(
        uri, 
        mode: LaunchMode.externalApplication,
      );
      
      if (launched && mounted) {
        setState(() => _portalOpened = true);
      } else {
        if (mounted) setState(() => _error = 'No se pudo abrir el navegador. Copia este link: $url');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        setState(() => _error = msg.contains('PROFILE_LIMIT_REACHED')
            ? 'Tu plan ha alcanzado el límite de perfiles. Contacta a soporte.'
            : msg);
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _verifying = true; _error = null; });
    await _loadStatus(refresh: true);
    if (mounted) setState(() { _verifying = false; _portalOpened = false; });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final artist = prov.activeArtist;

    if (artist == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, color: AppColors.textMuted, size: 56),
              SizedBox(height: 16),
              Text(
                'No hay perfil activo',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Crea tu perfil primero desde la sección Contenido',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final connectedPlatforms = _status.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final hasConnections = connectedPlatforms.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => _loadStatus(refresh: true),
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.accent.withValues(alpha: 0.06),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.share_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Conecta tus redes sociales',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Vincula tu cuenta de ${artist.name} con tus redes sociales.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Plataformas conectadas
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else ...[
            if (hasConnections) ...[
              const Text(
                'REDES CONECTADAS',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: connectedPlatforms
                    .map((p) => SocialPlatformChip(platform: p, connected: true))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Plataformas disponibles (estado)
            const Text(
              'ESTADO DE PLATAFORMAS',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 12),
            ..._platformItems(),
            const SizedBox(height: 24),

            // Botón conectar
            VidalisButton(
              label: hasConnections ? 'Gestionar Redes Conectadas' : 'Conectar Redes Sociales',
              onPressed: _connecting ? null : _connect,
              isLoading: _connecting,
              icon: Icons.link_rounded,
            ),

            // Botón verificar (aparece tras abrir el portal)
            if (_portalOpened) ...[
              const SizedBox(height: 12),
              VidalisButton(
                label: 'Ya conecté mis redes — Confirmar',
                onPressed: _verifying ? null : _verify,
                isLoading: _verifying,
                variant: VidalisButtonVariant.outlined,
                icon: Icons.refresh_rounded,
              ),
            ],

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _platformItems() {
    final prov = context.read<AppProvider>();
    final plan = prov.user?.plan ?? 'Mini';

    final allPlatforms = [
      ('instagram', 'Instagram', Icons.camera_alt_outlined, Color(0xFFE1306C)),
      ('tiktok',    'TikTok',    Icons.music_note_outlined,  Color(0xFF00F2EA)),
      ('facebook',  'Facebook',  Icons.facebook_outlined,    Color(0xFF1877F2)),
      ('youtube',   'YouTube',   Icons.play_circle_outline,  Color(0xFFFF0000)),
      ('linkedin',  'LinkedIn',  Icons.link_rounded,         Color(0xFF0077B5)),
    ];

    // Mapa de límites por plan (Sincronizado con Backend)
    final planLimits = {
      'Mini':        ['instagram', 'tiktok'],
      'Artista':     ['instagram', 'tiktok', 'facebook'],
      'Estrella':    ['instagram', 'tiktok', 'facebook', 'youtube', 'linkedin'],
      'Agencia Pro': ['instagram', 'tiktok', 'facebook', 'youtube', 'linkedin'],
    };

    final allowed = planLimits[plan] ?? planLimits['Mini']!;
    final platforms = allPlatforms.where((p) => allowed.contains(p.$1)).toList();

    return platforms.map((item) {
      final (id, label, icon, color) = item;
      final connected = _status[id] ?? false;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: connected ? color.withValues(alpha: 0.08) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: connected ? color.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: connected ? color : AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: connected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (connected)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  const SizedBox(width: 4),
                  Text('Conectado',
                      style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              )
            else
              Text('Sin conectar',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }).toList();
  }
}
