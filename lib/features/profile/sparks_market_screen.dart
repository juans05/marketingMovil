import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_provider.dart';

class SparksMarketScreen extends StatefulWidget {
  const SparksMarketScreen({super.key});

  @override
  State<SparksMarketScreen> createState() => _SparksMarketScreenState();
}

class _SparksMarketScreenState extends State<SparksMarketScreen> {
  final TextEditingController _couponController = TextEditingController();
  bool _isRedeeming = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Centro de Energía', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceHeader(context),
            const SizedBox(height: 30),
            
            // --- TARJETA INFORMATIVA SEGURA ---
            _buildInfoCard(context),
            
            const SizedBox(height: 30),
            
            // --- SECCIÓN DE CUPONES ---
            _buildCouponSection(context),
            
            const SizedBox(height: 40),
            
            // --- BOTÓN DE SOPORTE ---
            _buildSupportLink(context),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceHeader(BuildContext context) {
    final balance = context.watch<AppProvider>().user?.sparksBalance ?? 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Balance de Energía',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '$balance Sparks',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 48),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Planes y Energía',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Planes y Energía: Vidalis es una plataforma multiplataforma. Puedes gestionar tus Sparks y beneficios de cuenta desde tu portal web administrativo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿TIENES UN CÓDIGO?',
          style: TextStyle(
            color: AppColors.textMuted,
            letterSpacing: 1.5,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: const InputDecoration(
                    hintText: 'Ingresa código promocional',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isRedeeming ? null : _handleRedeem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black, // Texto oscuro para contrastar con Cian
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isRedeeming 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Canjear', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportLink(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _launchWhatsApp(),
        icon: const Icon(Icons.help_outline_rounded, size: 20, color: Colors.white70),
        label: const Text('Centro de Ayuda y Soporte Técnico'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70, // Color más claro para que se vea
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Future<void> _handleRedeem() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isRedeeming = true);
    final success = await context.read<AppProvider>().redeemCoupon(code);
    setState(() => _isRedeeming = false);

    if (mounted) {
      if (success) {
        _couponController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Código canjeado con éxito!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AppProvider>().errorMessage ?? 'Código inválido')),
        );
      }
    }
  }


  Future<void> _launchWhatsApp() async {
    const phoneNumber = '51902191948'; 
    final url = Uri.parse('https://wa.me/$phoneNumber?text=Hola, necesito ayuda con mi plan administrativo en Vidalis.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
