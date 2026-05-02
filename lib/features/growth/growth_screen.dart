import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/growth_model.dart';
import '../../core/services/app_provider.dart';
import 'screens/ab_testing_screen.dart';
import 'screens/best_time_screen.dart';
import 'screens/content_strategy_screen.dart';
import 'screens/growth_insights_screen.dart';
import 'screens/ad_copy_screen.dart';
import 'screens/viral_score_history_screen.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  BestTimeData? _bestTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prov = context.read<AppProvider>();
    final artistId = prov.activeArtist?.id;
    if (artistId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final bestTime = await prov.api.getGrowthBestTime(artistId);
      if (mounted) setState(() => _bestTime = bestTime);
    } catch (_) {
      // Hero degrades gracefully to generic recommendation
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          _loading ? _HeroSkeleton() : _HeroCard(data: _bestTime),
          const SizedBox(height: 20),
          const Text(
            'HERRAMIENTAS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _SectionTile(
            icon: '🧪',
            title: 'A/B Testing de Captions',
            subtitle: 'Descubre qué copy convierte más',
            color: AppColors.warning,
            onTap: () => _navigate(const ABTestingScreen()),
          ),
          _SectionTile(
            icon: '⏰',
            title: 'Mejor Hora para Publicar',
            subtitle: 'Basado en tu historial real',
            color: AppColors.primary,
            onTap: () => _navigate(const BestTimeScreen()),
          ),
          _SectionTile(
            icon: '🎯',
            title: 'Estrategia de Contenido',
            subtitle: 'Plan semanal recomendado por IA',
            color: AppColors.success,
            onTap: () => _navigate(const ContentStrategyScreen()),
          ),
          _SectionTile(
            icon: '💡',
            title: 'Insights de Crecimiento',
            subtitle: 'Patrones detectados en tus videos',
            color: AppColors.info,
            onTap: () => _navigate(const GrowthInsightsScreen()),
          ),
          _SectionTile(
            icon: '📣',
            title: 'Copy para Anuncios',
            subtitle: 'Listo para Meta Ads y TikTok Ads',
            color: AppColors.accent,
            onTap: () => _navigate(const AdCopyScreen()),
          ),
          _SectionTile(
            icon: '🏆',
            title: 'Viral Score Histórico',
            subtitle: 'Evolución de tu potencial viral',
            color: const Color(0xFFFBBF24),
            onTap: () => _navigate(const ViralScoreHistoryScreen()),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({this.data});
  final BestTimeData? data;

  @override
  Widget build(BuildContext context) {
    final day = data?.dayOfWeek ?? 'Hoy';
    final time = data?.formattedHour ?? '8:00 PM';
    final multiplier = data?.reachMultiplier ?? 1.0;
    final recommendation = data?.recommendation ?? 'Publica hoy para maximizar tu alcance';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.accent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '⏰  PUBLICA AHORA',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (multiplier > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${((multiplier - 1) * 100).toStringAsFixed(0)}% alcance',
                    style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: time,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            recommendation,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BestTimeScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: AppColors.primaryGlow(radius: 10),
              child: const Center(
                child: Text(
                  'VER ESTRATEGIA COMPLETA →',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: AppColors.glassCard(radius: 20),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppColors.glassCard(radius: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
