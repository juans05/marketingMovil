import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/artist_model.dart';
import '../../core/services/app_provider.dart';
import '../analytics/analytics_screen.dart';
import '../content/content_screen.dart';
import '../planning/planning_screen.dart';
import '../artists/artists_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().init();
    });
  }

  List<_NavItem> _navItems(bool isAgency) => [
        const _NavItem(
            label: 'Analítica', icon: Icons.bar_chart_rounded),
        const _NavItem(
            label: 'Contenido', icon: Icons.video_library_rounded),
        const _NavItem(
            label: 'Calendario', icon: Icons.calendar_month_rounded),
        if (isAgency)
          const _NavItem(label: 'Marcas', icon: Icons.people_rounded),
      ];

  Widget _screen(int index, bool isAgency) {
    switch (index) {
      case 0:
        return const AnalyticsScreen();
      case 1:
        return const ContentScreen();
      case 2:
        return const PlanningScreen();
      case 3:
        if (isAgency) return const ArtistsScreen();
        return const AnalyticsScreen();
      default:
        return const AnalyticsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isAgency = prov.isAgency;
    final navItems = _navItems(isAgency);

    // Clamp nav index
    final safeIndex = _navIndex.clamp(0, navItems.length - 1);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: _VidalisAppBar(
        user: prov.user?.name ?? '',
        activeArtist: prov.activeArtist,
        artists: prov.artists,
        isAgency: isAgency,
        onArtistSelected: prov.setActiveArtist,
        onLogout: () async {
          await prov.logout();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
        onApiConfig: () => _showApiConfig(context, prov),
      ),
      body: _screen(safeIndex, isAgency),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.bgCard,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon, color: AppColors.textMuted),
                  selectedIcon: Icon(item.icon, color: AppColors.primary),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }

  void _showApiConfig(BuildContext ctx, AppProvider prov) {
    final ctrl = TextEditingController(text: prov.api.baseUrl);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Servidor API',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              prov.api.updateBaseUrl(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _VidalisAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _VidalisAppBar({
    required this.user,
    required this.activeArtist,
    required this.artists,
    required this.isAgency,
    required this.onArtistSelected,
    required this.onLogout,
    required this.onApiConfig,
  });

  final String user;
  final ArtistModel? activeArtist;
  final List<ArtistModel> artists;
  final bool isAgency;
  final void Function(ArtistModel) onArtistSelected;
  final VoidCallback onLogout;
  final VoidCallback onApiConfig;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgSecondary,
      elevation: 0,
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
            child: const Text(
              'VIDALIS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          // AI pulse indicator
          const SizedBox(width: 8),
          _PulseIndicator(),
        ],
      ),
      actions: [
        // Artist selector (agencies only)
        if (isAgency && artists.isNotEmpty)
          GestureDetector(
            onTap: () => _showArtistPicker(context),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    activeArtist?.name ?? 'Seleccionar',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.expand_more,
                      size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        // User menu
        IconButton(
          onPressed: () => _showUserMenu(context),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: Text(
              user.isNotEmpty ? user[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showArtistPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Seleccionar Artista',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
            ),
            ...artists.map((a) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(a.name[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary)),
                  ),
                  title: Text(a.name,
                      style: const TextStyle(color: AppColors.textPrimary)),
                  subtitle: a.genre != null
                      ? Text(a.genre!,
                          style:
                              const TextStyle(color: AppColors.textSecondary))
                      : null,
                  trailing: activeArtist?.id == a.id
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    onArtistSelected(a);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Configurar servidor API',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                onApiConfig();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success.withOpacity(_anim.value),
        ),
      ),
    );
  }
}
