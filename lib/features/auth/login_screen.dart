import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_provider.dart';
import '../../shared/widgets/vidalis_button.dart';
import '../../shared/widgets/vidalis_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  bool _obscureLogin = true;
  bool _obscureReg = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _login(AppProvider prov) async {
    if (!_loginForm.currentState!.validate()) return;
    final ok = await prov.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (ok && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else if (mounted && prov.errorMessage != null) {
      _showError(prov.errorMessage!);
      prov.clearError();
    }
  }

  Future<void> _loginWithGoogle(AppProvider prov) async {
    final ok = await prov.loginWithGoogle();
    if (ok && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else if (mounted && prov.errorMessage != null) {
      _showError(prov.errorMessage!);
      prov.clearError();
    }
  }

  Future<void> _register(AppProvider prov) async {
    if (!_registerForm.currentState!.validate()) return;
    final ok = await prov.register(
      _nameCtrl.text.trim(),
      _regEmailCtrl.text.trim(),
      _regPasswordCtrl.text,
      _birthDateCtrl.text,
    );
    if (ok && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else if (mounted && prov.errorMessage != null) {
      _showError(prov.errorMessage!);
      prov.clearError();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.bgCard,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateCtrl.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Logo
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                child: const Text(
                  'VIDALIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Marketing Digital con IA',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Iniciar Sesión'),
                    Tab(text: 'Registrarse'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 520,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _LoginForm(
                      formKey: _loginForm,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      obscure: _obscureLogin,
                      onToggleObscure: () =>
                          setState(() => _obscureLogin = !_obscureLogin),
                      onSubmit: () => _login(prov),
                      onGoogleLogin: () => _loginWithGoogle(prov),
                      isLoading: prov.isLoading,
                    ),
                    _RegisterForm(
                      formKey: _registerForm,
                      nameCtrl: _nameCtrl,
                      emailCtrl: _regEmailCtrl,
                      passwordCtrl: _regPasswordCtrl,
                      birthDateCtrl: _birthDateCtrl,
                      onSelectDate: () => _selectDate(context),
                      obscure: _obscureReg,
                      onToggleObscure: () =>
                          setState(() => _obscureReg = !_obscureReg),
                      onSubmit: () => _register(prov),
                      onGoogleLogin: () => _loginWithGoogle(prov),
                      isLoading: prov.isLoading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogleLogin,
    required this.isLoading,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleLogin;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          VidalisInput(
            label: 'Email',
            hint: 'tu@email.com',
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Email inválido' : null,
          ),
          const SizedBox(height: 16),
          VidalisInput(
            label: 'Contraseña',
            hint: '••••••••',
            controller: passwordCtrl,
            obscureText: obscure,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 24),
          VidalisButton(
            label: 'Iniciar Sesión',
            onPressed: isLoading ? null : onSubmit,
            isLoading: isLoading,
            icon: Icons.login,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('o usa', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: isLoading ? null : onGoogleLogin,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                    height: 22,
                    placeholder: (_, __) => const Icon(Icons.g_mobiledata, color: Colors.blue),
                    errorWidget: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continuar con Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.birthDateCtrl,
    required this.onSelectDate,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogleLogin,
    required this.isLoading,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController birthDateCtrl;
  final VoidCallback onSelectDate;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleLogin;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          VidalisInput(
            label: 'Tu Nombre Completo',
            hint: 'Ej: Juan Pérez',
            controller: nameCtrl,
            prefixIcon: Icons.person_outline,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          VidalisInput(
            label: 'Fecha de nacimiento',
            hint: 'AAAA-MM-DD',
            controller: birthDateCtrl,
            prefixIcon: Icons.calendar_today_outlined,
            readOnly: true,
            onTap: onSelectDate,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          VidalisInput(
            label: 'Email',
            hint: 'tu@email.com',
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Email inválido' : null,
          ),
          const SizedBox(height: 12),
          VidalisInput(
            label: 'Contraseña',
            hint: '••••••••',
            controller: passwordCtrl,
            obscureText: obscure,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 20),
          VidalisButton(
            label: 'Crear Cuenta',
            onPressed: isLoading ? null : onSubmit,
            isLoading: isLoading,
            icon: Icons.person_add_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('o registrate con', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: isLoading ? null : onGoogleLogin,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                    height: 22,
                    placeholder: (_, __) => const Icon(Icons.g_mobiledata, color: Colors.blue),
                    errorWidget: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continuar con Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
