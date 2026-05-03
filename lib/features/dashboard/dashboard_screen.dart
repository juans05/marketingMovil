import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/artist_model.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/upload_banner.dart';
import '../analytics/analytics_screen.dart';
import '../content/content_screen.dart';
import '../planning/planning_screen.dart';
import '../artists/artists_screen.dart';
import '../social/social_connect_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/sparks_market_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().init();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_NavItem> _navItems(bool isAgency) => [
        const _NavItem(label: 'Contenido',  icon: Icons.video_library_rounded),
        const _NavItem(label: 'Analítica',  icon: Icons.graphic_eq_rounded),
        const _NavItem(label: 'Calendario', icon: Icons.calendar_month_rounded),
        if (isAgency)
          const _NavItem(label: 'Marcas',       icon: Icons.people_rounded)
        else
          const _NavItem(label: 'Redes',        icon: Icons.share_rounded),
      ];

  Widget _screen(int index, bool isAgency) {
    switch (index) {
      case 0:
        return const _KeepAliveContent(child: ContentScreen());
      case 1:
        return const _KeepAliveContent(child: AnalyticsScreen());
      case 2:
        return const _KeepAliveContent(child: PlanningScreen());
      case 3:
        return _KeepAliveContent(child: isAgency ? const ArtistsScreen() : const SocialConnectScreen());
      default:
        return const _KeepAliveContent(child: ContentScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.select((AppProvider p) => (
      name: p.user?.name ?? '',
      email: p.user?.email ?? '',
      plan: p.user?.plan ?? 'free',
      sparks: p.user?.sparksBalance ?? 0,
      isAgency: p.isAgency,
      activeArtist: p.activeArtist,
      artists: p.artists,
    ));
    final navItems = _navItems(userState.isAgency);
    final safeIndex = _navIndex.clamp(0, navItems.length - 1);

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bgPrimary,
      appBar: _VidalisAppBar(
        user: userState.name,
        userEmail: userState.email,
        userPlan: userState.plan,
        activeArtist: userState.activeArtist,
        artists: userState.artists,
        isAgency: userState.isAgency,
        sparksBalance: userState.sparks,
        onArtistSelected: context.read<AppProvider>().setActiveArtist,
        onLogout: () async {
          await context.read<AppProvider>().logout();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(navItems.length, (i) => _screen(i, userState.isAgency)),
          ),
          const UploadBannerOverlay(),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        decoration: AppColors.glassCard(radius: 30),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: AppColors.primary.withValues(alpha: 0.15),
              selectedIndex: safeIndex,
              onDestinationSelected: (i) {
                setState(() => _navIndex = i);
                _pageController.jumpToPage(i);
              },
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              height: 65,
              destinations: navItems
                  .map((item) => NavigationDestination(
                        icon: Icon(item.icon, color: AppColors.textMuted),
                        selectedIcon: Icon(item.icon, color: AppColors.primary, size: 28),
                        label: item.label,
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

}

class _KeepAliveContent extends StatefulWidget {
  const _KeepAliveContent({required this.child});
  final Widget child;

  @override
  State<_KeepAliveContent> createState() => _KeepAliveContentState();
}

class _KeepAliveContentState extends State<_KeepAliveContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
    required this.userEmail,
    required this.userPlan,
    required this.activeArtist,
    required this.artists,
    required this.isAgency,
    required this.sparksBalance,
    required this.onArtistSelected,
    required this.onLogout,
  });

  final String user;
  final String userEmail;
  final String userPlan;
  final ArtistModel? activeArtist;
  final List<ArtistModel> artists;
  final bool isAgency;
  final int sparksBalance;
  final void Function(ArtistModel) onArtistSelected;
  final VoidCallback onLogout;

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
              'vidalis', // Lowercase to match logo
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontFamily: 'Outfit', // Assuming generic modern font loaded or fallback
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PulseIndicator(),
          const SizedBox(width: 12),
          // Gamification: Streaks
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🔥', style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
                Text('3 Días', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Sparks Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Text('$sparksBalance', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
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
          onPressed: () => _showUserMenu(context, sparksBalance),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
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
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
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

  void _showUserMenu(BuildContext context, int balance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgInput,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Avatar grande
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  user.isNotEmpty ? user[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userEmail,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              // Badge del plan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  userPlan.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Sparks info in menu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Energía Disponible', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                              Text('Cada video gasta 10 Sparks', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('$balance', style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SparksMarketScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Recargar Sparks (Energía)'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppColors.primary),
                title: const Text('Mi Perfil',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Ver y editar datos personales',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
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
              const SizedBox(height: 24),
            ],
          ),
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: _anim.value),
          ),
        ),
      ),
    );
  }
}
