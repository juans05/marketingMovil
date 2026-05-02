import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';

class GrowthLockedView extends StatelessWidget {
  const GrowthLockedView({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<AppProvider>().stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _GradientBadge(),
        const SizedBox(height: 20),
        if (stats != null) _FreeInsightCard(stats: stats),
        const SizedBox(height: 12),
        _LockedInsightCard(
          icon: '⏰',
          title: 'Mejor hora para publicar',
          description: 'Análisis personalizado basado en tu historial real',
        ),
        const SizedBox(height: 8),
        _LockedInsightCard(
          icon: '🎯',
          title: 'Estrategia semanal',
          description: 'Qué publicar esta semana para maximizar alcance',
        ),
        const SizedBox(height: 8),
        _LockedInsightCard(
          icon: '🧪',
          title: 'A/B Testing de captions',
          description: 'Descubre cuál copy convierte 3x más',
        ),
        const SizedBox(height: 8),
        _LockedInsightCard(
          icon: '📣',
          title: 'Copy para anuncios',
          description: 'Listo para Meta Ads y TikTok Ads',
        ),
        const SizedBox(height: 24),
        _UpgradeCTA(),
      ],
    );
  }
}

class _GradientBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.accent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('📈', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GROWTH PRO',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Inteligencia para crecer más rápido',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '✦ PRO',
              style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeInsightCard extends StatelessWidget {
  const _FreeInsightCard({required this.stats});
  final StatsModel stats;

  String _computeFreeInsight() {
    if (stats.platformBreakdown.isNotEmpty) {
      final best = stats.platformBreakdown.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      final name = best.key[0].toUpperCase() + best.key.substring(1);
      return '$name genera el mayor alcance en tu contenido';
    }
    if (stats.avgViralScore > 0) {
      return 'Tu viral score promedio es ${stats.avgViralScore.toStringAsFixed(1)}/10';
    }
    return 'Detectamos patrones de crecimiento en tu contenido';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🔮 MUESTRA DE TUS DATOS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'GRATIS',
                  style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _computeFreeInsight(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contenido más efectivo', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: stats.avgViralScore / 10,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '+${(stats.avgViralScore * 30).toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                '+ 3 insights bloqueados...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedInsightCard extends StatelessWidget {
  const _LockedInsightCard({
    required this.icon,
    required this.title,
    required this.description,
  });
  final String icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppColors.glassCard(radius: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(description,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, color: AppColors.accent, size: 18),
        ],
      ),
    );
  }
}

class _UpgradeCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sube al plan Estrella o Agencia Pro para activar Growth'),
            backgroundColor: AppColors.accent,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: AppColors.primaryGlow(radius: 14),
        child: const Center(
          child: Text(
            'DESBLOQUEAR MIS INSIGHTS →',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
