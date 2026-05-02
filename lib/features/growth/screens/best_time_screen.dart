import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/growth_model.dart';
import '../../../core/services/app_provider.dart';

class BestTimeScreen extends StatefulWidget {
  const BestTimeScreen({super.key});

  @override
  State<BestTimeScreen> createState() => _BestTimeScreenState();
}

class _BestTimeScreenState extends State<BestTimeScreen> {
  BestTimeData? _data;
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
      final data = await prov.api.getGrowthBestTime(artistId);
      if (mounted) setState(() => _data = data);
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
        title: const Text('⏰ Mejor Hora', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: AppColors.textMuted),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _data == null
                  ? const Center(child: Text('Sin datos', style: TextStyle(color: AppColors.textMuted)))
                  : _Content(data: _data!),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data});
  final BestTimeData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        // Hero time card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              const Text('MEJOR MOMENTO PARA PUBLICAR', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 16),
              Text(
                data.formattedHour,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 56, fontWeight: FontWeight.w900, height: 1),
              ),
              Text(
                data.dayOfWeek,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${data.reachMultiplier.toStringAsFixed(1)}x más alcance',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Recommendation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.glassCard(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡 ANÁLISIS', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 10),
              Text(data.recommendation, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Weekly heatmap placeholder
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.glassCard(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RENDIMIENTO POR DÍA', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 14),
              _WeeklyHeatmap(bestDay: data.dayOfWeek),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppColors.glassCard(radius: 12),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.warning, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Este análisis se actualiza automáticamente con cada video que publiques.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyHeatmap extends StatelessWidget {
  const _WeeklyHeatmap({required this.bestDay});
  final String bestDay;

  static const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _levels = [0.3, 0.6, 0.4, 0.9, 0.7, 0.5, 0.2];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_days.length, (i) {
        final level = _levels[i];
        final isBest = level == _levels.reduce((a, b) => a > b ? a : b);
        return Column(
          children: [
            Container(
              width: 36,
              height: 60,
              decoration: BoxDecoration(
                color: isBest
                    ? AppColors.primary.withValues(alpha: level)
                    : AppColors.primary.withValues(alpha: level * 0.5),
                borderRadius: BorderRadius.circular(8),
                border: isBest ? Border.all(color: AppColors.primary, width: 1.5) : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _days[i],
              style: TextStyle(
                color: isBest ? AppColors.primary : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isBest ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        );
      }),
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
