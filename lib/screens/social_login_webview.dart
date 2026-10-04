import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:agl_i18n/agl_i18n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SocialLoginWebView — hosts the backend-brokered OAuth flow.
//
// The backend runs the full OAuth 2.0 dance and redirects back with tokens in
// the URL, e.g. `pilotenroute://login?access_token=...&refresh_token=...` (or an
// https callback carrying the same query params). We intercept that navigation,
// parse the tokens, and pop them back to the caller.
//
// KNOWN LIMITATION: Google may reject OAuth performed inside an embedded
// WebView ('disallowed_useragent'). Apple/Facebook are generally fine.
// TODO(auth): for production use flutter_web_auth_2 / app_links external-browser
// flow so the system browser handles the OAuth handshake.
// ─────────────────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF0A1628);
const _kCyan = Color(0xFF00BCD4);

class SocialLoginWebView extends StatefulWidget {
  const SocialLoginWebView({
    super.key,
    required this.provider,
    required this.startUrl,
  });

  final String provider;
  final String startUrl;

  @override
  State<SocialLoginWebView> createState() => _SocialLoginWebViewState();
}

class _SocialLoginWebViewState extends State<SocialLoginWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.startUrl));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;

    // Success: tokens embedded in the query string (any scheme/host, incl.
    // custom schemes like pilotenroute://login?...).
    if (url.contains('access_token=')) {
      final params = _queryParams(url);
      final accessToken = params['access_token'] ?? '';
      final refreshToken = params['refresh_token'] ?? '';
      _finish({
        'access_token': accessToken,
        'refresh_token': refreshToken,
      });
      return NavigationDecision.prevent;
    }

    // Error redirect from the OAuth provider / backend.
    if (url.contains('error=')) {
      final params = _queryParams(url);
      final error = params['error_description'] ??
          params['error'] ??
          'Social sign-in failed.';
      _finish({'error': error});
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  /// Parses query parameters, tolerating custom URI schemes.
  Map<String, String> _queryParams(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.isNotEmpty) return uri.queryParameters;
      // Fallback: some redirects put params after a fragment.
      if (uri.fragment.contains('=')) {
        return Uri.splitQueryString(uri.fragment);
      }
    } catch (_) {
      // Fall through to manual parse.
    }
    final qIndex = url.indexOf('?');
    if (qIndex >= 0 && qIndex < url.length - 1) {
      return Uri.splitQueryString(url.substring(qIndex + 1));
    }
    return const {};
  }

  void _finish(Map<String, String> result) {
    if (_handled) return;
    _handled = true;
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          AglL10n.of(context)!.authSignIn,
          style: GoogleFonts.orbitron(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _kBg,
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: _kCyan),
            ),
        ],
      ),
    );
  }
}
