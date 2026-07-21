import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/supabase_config.dart';
import 'home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthGate — the app's root. Shows a brief splash while the persisted session
// restores, then routes to either the LoginScreen or the main app (HomeScreen).
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isInitialized) {
      return const _SplashScaffold();
    }
    if (auth.canEnterApp) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}

class _SplashScaffold extends StatelessWidget {
  const _SplashScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen — email/password sign-in against the org's Supabase backend,
// plus a one-tap "Use test account" button (shared QA account) and a
// "Continue as guest" option.
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final AuthService _auth = AuthService.instance;

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  static const Color _navy = Color(0xFF0A1628);
  static const Color _surface = Color(0xFF112240);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _amber = Color(0xFFFFB300);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() => _auth.loginEmail(_emailCtrl.text, _passwordCtrl.text));
  }

  Future<void> _useTestAccount() async {
    // One-tap sign-in with the shared QA account from SupabaseConfig.
    _emailCtrl.text = SupabaseConfig.qaEmail;
    _passwordCtrl.text = SupabaseConfig.qaPassword;
    await _run(() => _auth.signInWithTestAccount());
  }

  Future<void> _run(Future<AuthResult> Function() action) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.ok) {
      setState(() => _error = result.error ?? 'Sign in failed.');
    }
    // On success the AuthGate rebuilds automatically and shows the home screen.
  }

  void _continueAsGuest() {
    _auth.continueAsGuest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 24),
                    Text(
                      'PILOTENROUTE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complete Aviation Training Platform',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _auth.validateEmailField,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white54,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: _auth.validatePasswordField,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildError(_error!),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitting ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text('SIGN IN'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _useTestAccount,
                      icon: const Icon(Icons.badge_outlined, color: _amber),
                      label: const Text('Use test account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _amber,
                        side: const BorderSide(color: _amber),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _submitting ? null : _continueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: _cyan,
                      ),
                      child: const Text('Continue without signing in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 96,
      width: 96,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 140),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cyan.withValues(alpha: 0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/logo/pilot_enroute_icon.png',
          height: 88,
          width: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.flight_takeoff,
            color: _cyan,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF44336).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF44336)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF44336), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
