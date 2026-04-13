import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/stat_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  StatsModel? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final prov = context.read<AppProvider>();
    try {
      final stats = await prov.loadStats();
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _stats == null
                  ? _EmptyView(onRetry: _load)
                  : _Content(stats: _stats!),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats});
  final StatsModel stats;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _fmtChange(double v) =>
      v >= 0 ? '+${v.toStringAsFixed(1)}%' : '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            StatCard(
              label: 'Seguidores',
              value: _fmt(stats.totalFollowers),
              change: _fmtChange(stats.followersGrowth),
              icon: Icons.people_outline,
            ),
            StatCard(
              label: 'Reproducciones',
              value: _fmt(stats.totalViews),
              change: _fmtChange(stats.viewsGrowth),
              icon: Icons.play_circle_outline,
              iconColor: AppColors.accent,
            ),
            StatCard(
              label: 'Videos',
              value: stats.publishedVideos.toString(),
              icon: Icons.video_library_outlined,
              iconColor: AppColors.success,
            ),
            StatCard(
              label: 'Viral Score Avg',
              value: stats.avgViralScore.toStringAsFixed(1),
              icon: Icons.auto_awesome,
              iconColor: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Growth chart
        if (stats.growthData.isNotEmpty) ...[
          const Text(
            'Crecimiento de Seguidores',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: AppColors.glassCard(),
            child: _GrowthChart(data: stats.growthData),
          ),
          const SizedBox(height: 24),
        ],
        // Platform breakdown
        const Text(
          'Por Plataforma',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _PlatformBreakdown(
          tiktok: stats.growthData.fold(0, (s, e) => s + (e.views ~/ 3)),
          instagram: stats.growthData.fold(0, (s, e) => s + (e.views ~/ 3)),
          youtube: stats.growthData.fold(0, (s, e) => s + (e.views ~/ 3)),
          total: stats.totalViews,
        ),
      ],
    );
  }
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.data});
  final List<GrowthPoint> data;

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.followers.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.primary.withOpacity(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformBreakdown extends StatelessWidget {
  const _PlatformBreakdown({
    required this.tiktok,
    required this.instagram,
    required this.youtube,
    required this.total,
  });
  final int tiktok;
  final int instagram;
  final int youtube;
  final int total;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('TikTok', tiktok, const Color(0xFF00F2EA)),
      ('Instagram', instagram, const Color(0xFFE1306C)),
      ('YouTube', youtube, const Color(0xFFFF0000)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(),
      child: Column(
        children: items.map((item) {
          final (name, value, color) = item;
          final ratio = total > 0 ? value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                    Text('${(ratio * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(error,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
                onPressed: onRetry,
                child: const Text('Reintentar',
                    style: TextStyle(color: AppColors.primary))),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            const Text('Sin datos de analítica aún',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Sube y publica videos para ver estadísticas',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
                onPressed: onRetry,
                child: const Text('Actualizar',
                    style: TextStyle(color: AppColors.primary))),
          ],
        ),
      ),
    );
  }
}
