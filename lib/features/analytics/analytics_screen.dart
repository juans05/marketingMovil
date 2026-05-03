import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'style_settings_screen.dart';
import '../social/social_connect_screen.dart';
import '../growth/growth_screen.dart';
import '../growth/growth_locked_view.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/stat_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StatsModel? _stats;
  bool _loading = true;
  bool _auditing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _runAudit() async {
    if (_stats == null) return;
    
    final prov = context.read<AppProvider>();
    final isPro = _stats!.planName != 'Mini';

    if (!isPro) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La Auditoría Profunda es función del Plan Artista. ¡Sube de nivel!'),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Auditoría Profunda', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Vidalis leerá tus últimos 20 posts de Instagram para aprender qué te funciona mejor. ¿Permitir acceso?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empezar Auditoría'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _auditing = true);
    try {
      await prov.runDeepAudit(allowFullAudit: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auditoría completada. ADN Creativo actualizado.'), backgroundColor: AppColors.success),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _auditing = false);
    }
  }

  bool get _hasGrowthPlan {
    final plan = _stats?.planName ?? '';
    return plan == 'Estrella' || plan == 'Agencia Pro' || plan.toLowerCase().contains('growth');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: AppColors.bgPrimary,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: 'STATS'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('GROWTH'),
                    SizedBox(width: 4),
                    Text('✦', style: TextStyle(fontSize: 10, color: AppColors.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // STATS tab — existing content
              RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? _ErrorView(error: _error!, onRetry: _load)
                        : _stats == null
                            ? _EmptyView(onRetry: _load)
                            : Stack(
                                children: [
                                  _Content(stats: _stats!, onAudit: _runAudit),
                                  if (_auditing)
                                    Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: AppColors.primary),
                                            SizedBox(height: 16),
                                            Text('Analizando historial...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
              ),
              // GROWTH tab
              _hasGrowthPlan
                  ? const GrowthScreen()
                  : const GrowthLockedView(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats, required this.onAudit});
  final StatsModel stats;
  final VoidCallback onAudit;

  void _showHelp(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Estadísticas Reales',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => _showHelp(context, 'Métricas Reales', 
                    'Estas son las métricas acumuladas de todas tus redes conectadas. Se actualizan automáticamente cada vez que abres la app.'),
                  icon: const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                ),
                const Spacer(),
                IconButton(
                  onPressed: stats.totalFollowers == 0 
                    ? () => context.read<AppProvider>().syncStats() 
                    : () => context.read<AppProvider>().loadStats(), 
                  icon: const Icon(Icons.refresh, size: 20, color: AppColors.textMuted),
                  tooltip: 'Actualizar datos',
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StyleSettingsScreen()),
                  ),
                  icon: const Icon(Icons.psychology, size: 18, color: AppColors.accent),
                  label: const Text('Estilo',
                      style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAudit,
                  icon: const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                  label: const Text('Auditoría',
                      style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // KPI grid
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (context, index) {
            final kpis = [
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppColors.glassCard(),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Viral Score',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              stats.avgViralScore.toStringAsFixed(1),
                              style: TextStyle(
                                color: AppColors.viralScoreColor(stats.avgViralScore),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  BoxShadow(color: AppColors.viralScoreColor(stats.avgViralScore).withValues(alpha: 0.5), blurRadius: 12)
                                ],
                              ),
                            ),
                            const Text('/10', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        stats.avgViralScore >= 8 ? Icons.diamond : Icons.local_fire_department,
                        color: AppColors.viralScoreColor(stats.avgViralScore),
                        size: 28,
                      ),
                    )
                  ],
                ),
              ),
            ];
            return kpis[index];
          },
        ),
        const SizedBox(height: 24),
        // Growth chart
        Row(
          children: [
            const Text(
              'Crecimiento de Seguidores',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              onPressed: () => _showHelp(context, 'Crecimiento', 
                'Este gráfico muestra la tendencia de tus seguidores en los últimos 7 días combinando todas tus plataformas.'),
              icon: const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if ((stats.totalFollowers > 0 || stats.totalViews > 0) && stats.growthData.isNotEmpty)
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: AppColors.glassCard(),
            child: _GrowthChart(data: stats.growthData),
          )
        else if (context.read<AppProvider>().activeArtist?.activePlatforms.isNotEmpty ?? false)
          _GatheringDataCard()
        else
          _ConnectSocialsCard(),
        const SizedBox(height: 32),
        // Desglose de Interacciones (Nuevo indicador útil)
        if (stats.totalLikes > 0 || stats.totalComments > 0) ...[
          Row(
            children: [
              const Text(
                'Interacciones Totales',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => _showHelp(context, 'Interacciones', 
                  'Suma de todos los Likes, Comentarios, Compartidos y Guardados de tus publicaciones.'),
                icon: const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InteractionsBreakdown(stats: stats),
        ],
        const SizedBox(height: 32),
        // Distribución por Red Social — solo cuando hay más de una plataforma
        if (stats.platformBreakdown.length > 1) ...[
          Row(
            children: [
              const Text(
                'Rendimiento por Red Social',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => _showHelp(context, 'Rendimiento', 
                  'Aquí ves qué red social te está dando más resultados (alcance y vistas).'),
                icon: const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PlatformBreakdown(
            breakdown: stats.platformBreakdown,
            total: stats.totalViews,
          ),
        ],
      ],
    );
  }
}

class _ConnectSocialsCard extends StatelessWidget {
  const _ConnectSocialsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.glassCard(),
      child: Column(
        children: [
          const Icon(Icons.link_off, color: AppColors.textMuted, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Sin datos de seguidores',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Conecta tus redes sociales para ver el crecimiento real de tu audiencia.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialConnectScreen())),
            icon: const Icon(Icons.share, size: 16, color: AppColors.primary),
            label: const Text('Conectar Redes', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GatheringDataCard extends StatelessWidget {
  const _GatheringDataCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.glassCard(),
      child: const Column(
        children: [
          Icon(Icons.hourglass_empty, color: AppColors.accent, size: 36),
          SizedBox(height: 12),
          Text(
            'Recolectando Datos',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          SizedBox(height: 6),
          Text(
            '¡Tus redes están conectadas! Vidalis está consolidando tu base de datos de seguidores históricos. Toma hasta 24 horas.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0),
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

class _InteractionsBreakdown extends StatelessWidget {
  const _InteractionsBreakdown({required this.stats});
  final StatsModel stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InteractionItem(
            label: 'Likes',
            value: stats.totalLikes,
            icon: Icons.favorite_border,
            color: Colors.redAccent,
          ),
          _InteractionItem(
            label: 'Coments',
            value: stats.totalComments,
            icon: Icons.chat_bubble_outline,
            color: Colors.blueAccent,
          ),
          _InteractionItem(
            label: 'Shares',
            value: stats.totalShares,
            icon: Icons.ios_share,
            color: Colors.greenAccent,
          ),
          _InteractionItem(
            label: 'Saves',
            value: stats.totalSaves,
            icon: Icons.bookmark_border,
            color: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }
}

class _InteractionItem extends StatelessWidget {
  const _InteractionItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : value.toString(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _PlatformBreakdown extends StatelessWidget {
  const _PlatformBreakdown({
    required this.breakdown,
    required this.total,
  });
  final Map<String, int> breakdown;
  final int total;

  @override
  Widget build(BuildContext context) {
    // Definimos colores para las plataformas conocidas
    const platformColors = {
      'tiktok': Color(0xFF00F2EA),
      'instagram': Color(0xFFE1306C),
      'youtube': Color(0xFFFF0000),
      'facebook': Color(0xFF1877F2),
    };

    // Si el breakdown está vacío, no mostramos nada o un mensaje
    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(),
      child: Column(
        children: breakdown.entries.map((entry) {
          final name = entry.key;
          final value = entry.value;
          final color = platformColors[name.toLowerCase()] ?? AppColors.primary;
          final ratio = total > 0 ? value / total : 0.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name[0].toUpperCase() + name.substring(1),
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
