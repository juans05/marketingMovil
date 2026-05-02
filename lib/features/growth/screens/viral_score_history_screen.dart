import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/growth_model.dart';
import '../../../core/services/app_provider.dart';

class ViralScoreHistoryScreen extends StatefulWidget {
  const ViralScoreHistoryScreen({super.key});

  @override
  State<ViralScoreHistoryScreen> createState() => _ViralScoreHistoryScreenState();
}

class _ViralScoreHistoryScreenState extends State<ViralScoreHistoryScreen> {
  List<ViralScorePoint> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final prov = context.read<AppProvider>();
    final artistId = prov.activeArtist?.id;
    if (artistId == null) { setState(() => _loading = false); return; }
    try {
      final history = await prov.api.getViralHistory(artistId);
      if (mounted) setState(() => _history = history);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text('🏆 Viral Score', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppColors.textMuted))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _history.isEmpty
                  ? const _EmptyView()
                  : _Content(history: _history),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.history});
  final List<ViralScorePoint> history;

  double get _avg => history.isEmpty ? 0 : history.map((p) => p.score).reduce((a, b) => a + b) / history.length;
  double get _max => history.isEmpty ? 0 : history.map((p) => p.score).reduce((a, b) => a > b ? a : b);
  ViralScorePoint? get _best => history.isEmpty ? null : history.reduce((a, b) => a.score > b.score ? a : b);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        // KPI row
        Row(
          children: [
            _ScoreKPI(label: 'PROMEDIO', score: _avg, icon: Icons.show_chart),
            const SizedBox(width: 12),
            _ScoreKPI(label: 'MÁXIMO', score: _max, icon: Icons.emoji_events),
          ],
        ),
        const SizedBox(height: 20),
        // Chart
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.glassCard(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EVOLUCIÓN', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: _ScoreChart(history: history)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Best video
        if (_best != null) ...[
          const Text('MEJOR VIDEO', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.warning.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_best!.videoTitle ?? 'Video destacado', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        '${_best!.date.day}/${_best!.date.month}/${_best!.date.year}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  _best!.score.toStringAsFixed(1),
                  style: TextStyle(
                    color: AppColors.viralScoreColor(_best!.score),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        // History list
        const Text('HISTORIAL', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        ...history.reversed.take(10).map((p) => _HistoryRow(point: p)),
      ],
    );
  }
}

class _ScoreKPI extends StatelessWidget {
  const _ScoreKPI({required this.label, required this.score, required this.icon});
  final String label;
  final double score;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.glassCard(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.viralScoreColor(score), size: 18),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: score.toStringAsFixed(1),
                    style: TextStyle(
                      color: AppColors.viralScoreColor(score),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text: '/10',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  const _ScoreChart({required this.history});
  final List<ViralScorePoint> history;

  @override
  Widget build(BuildContext context) {
    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.score);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              interval: 5,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              s.y.toStringAsFixed(1),
              TextStyle(color: AppColors.viralScoreColor(s.y), fontWeight: FontWeight.w700),
            )).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: AppColors.primaryGradient,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.viralScoreColor(spot.y),
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0)],
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.point});
  final ViralScorePoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppColors.glassCard(radius: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.videoTitle ?? 'Video', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                Text('${point.date.day}/${point.date.month}/${point.date.year}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            point.score.toStringAsFixed(1),
            style: TextStyle(color: AppColors.viralScoreColor(point.score), fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Sin historial aún', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Publica videos para ver cómo evoluciona tu viral score', style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
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
