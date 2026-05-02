import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/growth_model.dart';
import '../../../core/services/app_provider.dart';

class ContentStrategyScreen extends StatefulWidget {
  const ContentStrategyScreen({super.key});

  @override
  State<ContentStrategyScreen> createState() => _ContentStrategyScreenState();
}

class _ContentStrategyScreenState extends State<ContentStrategyScreen> {
  List<ContentStrategyItem> _items = [];
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
      final items = await prov.api.getGrowthStrategy(artistId);
      if (mounted) setState(() => _items = items);
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
        title: const Text('🎯 Estrategia Semanal', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppColors.textMuted))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const _EmptyView()
                  : _Content(items: _items),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.items});
  final List<ContentStrategyItem> items;

  @override
  Widget build(BuildContext context) {
    final recommended = items.where((i) => !i.avoid).toList();
    final avoid = items.where((i) => i.avoid).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.success.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: const Column(
            children: [
              Text('ESTA SEMANA PUBLICA', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              SizedBox(height: 4),
              Text('Recomendaciones basadas en tu historial de engagement', style: TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (recommended.isNotEmpty) ...[
          const Text('✅ RECOMENDADO', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...recommended.map((item) => _StrategyCard(item: item)),
          const SizedBox(height: 20),
        ],
        if (avoid.isNotEmpty) ...[
          const Text('⚠️ EVITAR ESTA SEMANA', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...avoid.map((item) => _StrategyCard(item: item)),
        ],
      ],
    );
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({required this.item});
  final ContentStrategyItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.avoid ? AppColors.warning : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(radius: 14),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.contentType, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text(item.reason, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!item.avoid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'x${item.recommendedCount}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
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
            Text('🎯', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Estrategia no disponible', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Publica más videos para que la IA aprenda tu estilo', style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
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
