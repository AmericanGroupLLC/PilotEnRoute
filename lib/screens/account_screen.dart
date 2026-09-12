import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/backend_config.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import 'social_login_webview.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AccountScreen — REAL AmericanGroupLLC accounts + local backup/restore.
//
// Auth (email/password, social, phone-OTP) is handled by the singleton
// AuthService.instance, talking to the AmericanGroupLLC backend. Backup/Restore
// still uses a local CloudSyncService instance, exactly as before.
// ─────────────────────────────────────────────────────────────────────────────

// Palette (matches app conventions).
const _kBg = Color(0xFF0A1628);
const _kCard = Color(0xFF112240);
const _kCyan = Color(0xFF00BCD4);
const _kAmber = Color(0xFFFFB300);
const _kRed = Color(0xFFF44336);
const _kGreen = Color(0xFF4CAF50);

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _AuthTab { email, social, phone }

class _AccountScreenState extends State<AccountScreen> {
  // Singleton — do NOT dispose it here (shared app-wide).
  final AuthService _auth = AuthService.instance;
  // Local instance, owned by this screen (as before).
  final CloudSyncService _sync = CloudSyncService();

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  _AuthTab _tab = _AuthTab.email;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _auth.init();
    _sync.init();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    // NOTE: _auth is the app-wide singleton; do not dispose it.
    _sync.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _submitEmail() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _submitting = true);
    final AuthResult result = _isSignUp
        ? await _auth.registerEmail(
            _emailCtrl.text,
            _passwordCtrl.text,
            name: _nameCtrl.text,
          )
        : await _auth.loginEmail(_emailCtrl.text, _passwordCtrl.text);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.ok) {
      _passwordCtrl.clear();
      _showSnack(_isSignUp ? 'Account created' : 'Signed in', _kGreen);
    } else {
      _showSnack(result.error ?? 'Something went wrong', _kRed);
    }
  }

  Future<void> _social(String provider) async {
    final startUrl = _auth.socialStartUrl(provider);
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => SocialLoginWebView(
          provider: provider,
          startUrl: startUrl,
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      // User cancelled / backed out.
      return;
    }
    if (result['error'] != null) {
      _showSnack(result['error']!, _kRed);
      return;
    }
    final access = result['access_token'] ?? '';
    final refreshTok = result['refresh_token'] ?? '';

    setState(() => _submitting = true);
    final res = await _auth.completeSocialLogin(
      accessToken: access,
      refreshToken: refreshTok,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.ok) {
      _showSnack('Signed in', _kGreen);
    } else {
      _showSnack(res.error ?? 'Social sign-in failed', _kRed);
    }
  }

  Future<void> _sendPhoneCode() async {
    // Real SMS delivery needs the Firebase client SDK (firebase_auth), which is
    // not a dependency here. Explain honestly, and offer the working test token.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'SMS setup required',
          style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Sending a real verification code by SMS requires the Firebase SDK, '
          'which is not bundled in this build yet.\n\n'
          'You can still sign in against the live backend using the built-in '
          'test token (simulator mode).',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _usePhoneTestToken();
            },
            child: Text(
              'Use test token',
              style: GoogleFonts.inter(
                color: _kCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtp() async {
    // TODO(firebase): once firebase_auth is integrated, exchange the SMS code
    // entered in _otpCtrl for a Firebase id_token, then call
    // _auth.verifyFirebasePhone(idToken). For now, only the test token flow is
    // wired to the backend.
    _showSnack(
      'Real OTP verification needs the Firebase SDK. Use the test token for now.',
      _kAmber,
    );
  }

  Future<void> _usePhoneTestToken() async {
    setState(() => _submitting = true);
    final res = await _auth.verifyFirebasePhone(AuthService.phoneTestToken);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.ok) {
      _showSnack('Signed in (phone test token)', _kGreen);
    } else {
      _showSnack(res.error ?? 'Phone sign-in failed', _kRed);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    _showSnack('Signed out', _kCyan);
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: BackendConfig.supportEmail,
      queryParameters: {'subject': 'PilotEnRoute support'},
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _showSnack('Could not open your mail app.', _kRed);
      }
    } catch (_) {
      if (mounted) _showSnack('Could not open your mail app.', _kRed);
    }
  }

  Future<void> _backupNow() async {
    await _sync.syncUp();
    if (!mounted) return;
    if (_sync.status == SyncStatus.idle) {
      _showSnack('Local backup saved on this device', _kGreen);
    } else {
      _showSnack(_sync.lastError ?? 'Backup failed', _kRed);
    }
  }

  Future<void> _restore() async {
    await _sync.syncDown();
    if (!mounted) return;
    if (_sync.status == SyncStatus.idle) {
      _showSnack('Restored from local backup', _kGreen);
    } else {
      _showSnack(_sync.lastError ?? 'Restore failed', _kRed);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('ACCOUNT'),
        backgroundColor: _kBg,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_auth, _sync]),
        builder: (context, _) {
          if (!_auth.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: _kCyan),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _auth.isAuthenticated
                ? _buildSignedIn()
                : _buildSignedOut(),
          );
        },
      ),
    );
  }

  // ── Signed-out ───────────────────────────────────────────────────────────────

  Widget _buildSignedOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _securedBanner(),
        const SizedBox(height: 16),
        _tabBar(),
        const SizedBox(height: 16),
        if (_tab == _AuthTab.email) _emailCard(),
        if (_tab == _AuthTab.social) _socialCard(),
        if (_tab == _AuthTab.phone) _phoneCard(),
        const SizedBox(height: 16),
        _supportRow(),
      ],
    );
  }

  Widget _tabBar() {
    return _card(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _tabButton('Email', _AuthTab.email),
          _tabButton('Social', _AuthTab.social),
          _tabButton('Phone', _AuthTab.phone),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _AuthTab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_tab != tab) setState(() => _tab = tab);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? _kCyan.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kCyan : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? _kCyan : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Email tab ────────────────────────────────────────────────────────────────

  Widget _emailCard() {
    return _card(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _signInUpToggle(),
            const SizedBox(height: 16),
            if (_isSignUp) ...[
              _textField(
                controller: _nameCtrl,
                label: 'Name (optional)',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
            ],
            _textField(
              controller: _emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _auth.validateEmailField,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: _auth.validatePasswordField,
              onSubmitted: (_) => _submitEmail(),
              suffix: IconButton(
                tooltip: 'Hide',
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              label: _isSignUp ? 'Create account' : 'Sign in',
              onPressed: _submitting ? null : _submitEmail,
              loading: _submitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _signInUpToggle() {
    return Row(
      children: [
        _miniToggle('Sign in', !_isSignUp, () {
          if (_isSignUp) setState(() => _isSignUp = false);
        }),
        const SizedBox(width: 8),
        _miniToggle('Sign up', _isSignUp, () {
          if (!_isSignUp) setState(() => _isSignUp = true);
        }),
      ],
    );
  }

  Widget _miniToggle(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? _kCyan.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _kCyan : Colors.white12),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? _kCyan : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Social tab ───────────────────────────────────────────────────────────────

  Widget _socialCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Continue with',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _socialButton('Continue with Google', Icons.g_mobiledata, 'google'),
          const SizedBox(height: 10),
          _socialButton('Continue with Apple', Icons.apple, 'apple'),
          const SizedBox(height: 10),
          _socialButton('Continue with Facebook', Icons.facebook, 'facebook'),
          const SizedBox(height: 10),
          Text(
            'Opens a secure AmericanGroupLLC sign-in page.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _socialButton(String label, IconData icon, String provider) {
    return OutlinedButton.icon(
      onPressed: _submitting ? null : () => _social(provider),
      icon: Icon(icon, color: Colors.white70),
      label: Text(label, style: GoogleFonts.inter(color: Colors.white70)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Colors.white12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ── Phone tab ────────────────────────────────────────────────────────────────

  Widget _phoneCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Phone sign-in',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'SMS is in test mode. Real codes require the Firebase SDK.',
            style: GoogleFonts.inter(color: _kAmber, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _phoneCtrl,
            label: 'Phone number (+E.164, e.g. +14155551234)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _sendPhoneCode,
            icon: const Icon(Icons.sms_outlined, color: _kCyan),
            label: Text('Send code', style: GoogleFonts.inter(color: _kCyan)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: _kCyan),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _otpCtrl,
            label: '6-digit code',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyOtp(),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _submitting ? null : _verifyOtp,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Verify code',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          _primaryButton(
            label: 'Use test token (simulator)',
            onPressed: _submitting ? null : _usePhoneTestToken,
            loading: _submitting,
          ),
        ],
      ),
    );
  }

  // ── Signed-in ────────────────────────────────────────────────────────────────

  Widget _buildSignedIn() {
    final user = _auth.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _profileCard(user),
        const SizedBox(height: 16),
        _syncCard(),
        const SizedBox(height: 16),
        _supportRow(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _submitting ? null : _signOut,
          icon: const Icon(Icons.logout, color: _kRed),
          label: Text(
            'Sign out',
            style: GoogleFonts.inter(color: _kRed, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: _kRed),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileCard(AuthUser? user) {
    final name = (user?.name != null && user!.name!.trim().isNotEmpty)
        ? user.name!.trim()
        : 'Pilot';
    final email = user?.email ?? '';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _kCyan.withValues(alpha: 0.15),
                child: Text(
                  _initials(name, email),
                  style: GoogleFonts.orbitron(
                    color: _kCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Role',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kCyan.withValues(alpha: 0.4)),
                ),
                child: Text(
                  (user?.role ?? UserRole.student).label,
                  style: GoogleFonts.inter(
                    color: _kCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _syncCard() {
    final busy = _sync.isBusy;
    final lastSynced = _sync.lastSyncedAt;
    final lastLabel = lastSynced == null
        ? 'Never'
        : DateFormat('MMM d, yyyy • h:mm a').format(lastSynced);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_outlined, color: _kCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Backup & Sync',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Last backup',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
              Text(
                lastLabel,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Backups stay on this device only.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _primaryButton(
                  label: 'Backup Now',
                  onPressed: busy ? null : _backupNow,
                  loading: busy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : _restore,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _kCyan),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Restore',
                    style: GoogleFonts.inter(
                      color: _kCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ───────────────────────────────────────────────────────────

  Widget _securedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: _kGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Secured by AmericanGroupLLC backend. Phone SMS is in test mode.',
              style: GoogleFonts.inter(color: _kGreen, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportRow() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // A ListTile paints its ink splash on the nearest Material ancestor,
      // which here is behind the card's opaque decoration — so the tap gave no
      // feedback at all. A transparent Material inside the card is the surface
      // the splash needs. (Flutter asserts on this in debug.)
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const Icon(Icons.support_agent_outlined, color: _kCyan),
        title: Text(
          'Contact Support',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          BackendConfig.supportEmail,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: _contactSupport,
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kCyan),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _kCyan,
        disabledBackgroundColor: _kCyan.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kBg),
            )
          : Text(
              label,
              style: GoogleFonts.inter(
                color: _kBg,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  String _initials(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email;
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
