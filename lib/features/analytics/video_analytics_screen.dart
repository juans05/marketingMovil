import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';

class VideoAnalyticsScreen extends StatefulWidget {
  const VideoAnalyticsScreen({super.key, required this.video});
  final VideoModel video;

  @override
  State<VideoAnalyticsScreen> createState() => _VideoAnalyticsScreenState();
}

class _VideoAnalyticsScreenState extends State<VideoAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  AnalyticsModel? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prov = context.read<AppProvider>();
      final analytics = await prov.api.getAnalytics(widget.video.id);
      if (mounted) setState(() => _analytics = analytics);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Estadísticas de Post',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_analytics == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Header with Video Preview and Icons
        _Header(video: widget.video, analytics: _analytics!),

        // Tabs
        TabBar(
          controller: _tab,
          indicatorColor: AppColors.textPrimary,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Interacción'),
            Tab(text: 'Público'),
          ],
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _ResumenTab(analytics: _analytics!),
              _InteraccionTab(analytics: _analytics!),
              const _ComingSoon(title: 'Público'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.video, required this.analytics});
  final VideoModel video;
  final AnalyticsModel analytics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Video Thumbnail
          Center(
            child: Container(
              height: 200,
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: video.thumbnailUrl != null
                    ? DecorationImage(
                        image: NetworkImage(video.thumbnailUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppColors.bgCard,
              ),
              child: video.thumbnailUrl == null
                  ? const Icon(Icons.video_file, color: AppColors.textMuted)
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          // Reaction strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ReactionItem(icon: Icons.favorite_border, value: analytics.likes),
              _ReactionItem(icon: Icons.chat_bubble_outline, value: analytics.comments),
              _ReactionItem(icon: Icons.repeat, value: analytics.shares),
              _ReactionItem(icon: Icons.send_outlined, value: analytics.shares), // Using shares as send proxy
              _ReactionItem(icon: Icons.bookmark_border, value: analytics.saves),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionItem extends StatelessWidget {
  const _ReactionItem({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textPrimary, size: 24),
        const SizedBox(height: 6),
        Text(
          value.toString(),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ResumenTab extends StatelessWidget {
  const _ResumenTab({required this.analytics});
  final AnalyticsModel analytics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Text(
              'Resumen',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _MiniStat(label: 'Visualizaciones', value: analytics.views.toString()),
            _MiniStat(label: 'Cuentas alcanzadas', value: analytics.reach.toString()),
            _MiniStat(label: 'Engagement', value: '${analytics.engagementRate.toStringAsFixed(1)}%'),
            _MiniStat(label: 'Nuevos seguidores', value: '0'), // Not tracked per post yet
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Text(
                  'Visualizaciones',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
              ],
            ),
            Text(analytics.views.toString(), style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        // Filter chips (Visual only)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(label: 'Todo', selected: true),
              _FilterChip(label: 'Seguidores', selected: false),
              _FilterChip(label: 'No seguidores', selected: false),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Graph
        SizedBox(
          height: 200,
          child: _PerformanceChart(history: analytics.history),
        ),
        const SizedBox(height: 12),
        // Legend
        Row(
          children: [
            _LegendItem(label: 'Este reel', color: AppColors.accent),
            const SizedBox(width: 16),
            _LegendItem(label: 'Tu reel típico', color: AppColors.textMuted, isDashed: true),
          ],
        ),
      ],
    );
  }
}

class _InteraccionTab extends StatelessWidget {
  const _InteraccionTab({required this.analytics});
  final AnalyticsModel analytics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
         const Text(
          'Interacciones',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _MetricRow(label: 'Me gusta', value: analytics.likes, icon: Icons.favorite_border),
        _MetricRow(label: 'Comentarios', value: analytics.comments, icon: Icons.chat_bubble_outline),
        _MetricRow(label: 'Compartidos', value: analytics.shares, icon: Icons.send_outlined),
        _MetricRow(label: 'Guardados', value: analytics.saves, icon: Icons.bookmark_border),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          const Spacer(),
          Text(value.toString(), style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2C2C2E) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.transparent : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _PerformanceChart extends StatelessWidget {
  const _PerformanceChart({required this.history});
  final List<VideoSnapshot> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('Sin datos históricos aún', style: TextStyle(color: AppColors.textMuted)));
    }

    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.views.toDouble());
    }).toList();

    // Typical reel line (Mocked for now)
    final typicalSpots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value.views * 0.8).toDouble() + 5);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: _getBottomTitles,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Typical line (dashed)
          LineChartBarData(
            spots: typicalSpots,
            isCurved: true,
            color: AppColors.textMuted,
            barWidth: 2,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
          // Current line
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(color: AppColors.textMuted, fontSize: 10);
    if (value == 0) return SideTitleWidget(axisSide: meta.axisSide, child: const Text('0', style: style));
    if (value == (history.length / 2).floorToDouble()) return SideTitleWidget(axisSide: meta.axisSide, child: const Text('12 h', style: style));
    if (value == history.length - 1) return SideTitleWidget(axisSide: meta.axisSide, child: const Text('24 h', style: style));
    return const SizedBox.shrink();
  }
}



class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color, this.isDashed = false});
  final String label;
  final Color color;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.analytics_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(
            'Estadísticas de $title en camino',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
        ],
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
            Text(error, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Reintentar', style: TextStyle(color: AppColors.primary))),
          ],
        ),
      ),
    );
  }
}
