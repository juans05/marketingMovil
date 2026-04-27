import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/vidalis_button.dart';
import '../../shared/widgets/vidalis_input.dart';

class StyleSettingsScreen extends StatefulWidget {
  const StyleSettingsScreen({super.key});

  @override
  State<StyleSettingsScreen> createState() => _StyleSettingsScreenState();
}

class _StyleSettingsScreenState extends State<StyleSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _hooksCtrl = TextEditingController();
  final _prohibitedCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _hooksCtrl.dispose();
    _prohibitedCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prov = context.read<AppProvider>();
    final ok = await prov.updateArtistStyle({
      'style_notes': _notesCtrl.text.trim(),
      'preferred_hooks': _hooksCtrl.text.trim(),
      'prohibited_topics': _prohibitedCtrl.text.trim(),
      'style_keywords': _keywordsCtrl.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'ADN Creativo actualizado' : 'Error al guardar'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artist = context.watch<AppProvider>().activeArtist;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Configurar IA: ${artist?.name ?? ""}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBox(),
              const SizedBox(height: 24),
              VidalisInput(
                label: 'Notas de Estilo',
                hint: 'Ej: Tono sarcástico, mucha energía, enfocado en el lujo...',
                controller: _notesCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              VidalisInput(
                label: 'Ganchos / Hooks favoritos',
                hint: 'Ej: Empezar con "No vas a creer lo que pasó...", usar mucha intriga...',
                controller: _hooksCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              VidalisInput(
                label: 'Palabras Clave de Marca',
                hint: 'Ej: Viral, Música, Estilo de vida, Emprendimiento...',
                controller: _keywordsCtrl,
              ),
              const SizedBox(height: 16),
              VidalisInput(
                label: 'Temas Prohibidos',
                hint: 'IA nunca hablará de esto. Ej: Competencia X, temas políticos, etc.',
                controller: _prohibitedCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              VidalisButton(
                label: 'Cargar en ADN de IA',
                onPressed: _save,
                icon: Icons.auto_awesome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personaliza tu Compañero de IA',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lo que escribas aquí servirá como guía para que la IA genere copys y estrategias que encajen 100% con tu estilo.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
