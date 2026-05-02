import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/growth_model.dart';
import '../../../core/services/app_provider.dart';

class GrowthInsightsScreen extends StatefulWidget {
  const GrowthInsightsScreen({super.key});

  @override
  State<GrowthInsightsScreen> createState() => _GrowthInsightsScreenState();
}

class _GrowthInsightsScreenState extends State<GrowthInsightsScreen> {
  List<GrowthInsight> _insights = [];
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
      final insights = await prov.api.getGrowthInsights(artistId);
      if (mounted) setState(() => _insights = insights);
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
        title: const Text('💡 Insights', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppColors.textMuted))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _insights.isEmpty
                  ? const _EmptyView()
                  : _Content(insights: _insights),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.insights});
  final List<GrowthInsight> insights;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.info.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Vidalis analizó todos tus videos publicados y detectó estos patrones de crecimiento.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('PATRONES DETECTADOS', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        ...insights.asMap().entries.map((e) => _InsightCard(insight: e.value, index: e.key)),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.index});
  final GrowthInsight insight;
  final int index;

  static const _icons = ['🎭', '🎵', '📸', '🎬', '✨', '💪', '🔥'];
  static const _colors = [AppColors.primary, AppColors.warning, AppColors.success, AppColors.info, AppColors.accent];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    final icon = _icons[index % _icons.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(insight.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              if (insight.impact > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${insight.impact.toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(insight.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          if (insight.impact > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (insight.impact / 400).clamp(0, 1),
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
          ],
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
            Text('💡', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Sin insights aún', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Necesitas al menos 5 videos publicados para que la IA detecte patrones', style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
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
