import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/backend_config.dart';
import 'auth_service.dart';

/// API key for the Anthropic Claude adapter.
///
/// Supply it at build/run time with:
///   flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
/// When empty, the assistant runs in an honest "offline reference" mode and
/// never pretends to be a live AI.
// TODO(ai-key): provide ANTHROPIC_API_KEY via --dart-define or a settings field
const String _anthropicApiKey =
    String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');

const String _anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
const String _anthropicModel = 'claude-sonnet-5';
const int _maxTokens = 1024;
const Duration _httpTimeout = Duration(seconds: 30);
const String _historyPrefsKey = 'ai_chat_history';

/// Roles used by the chat transcript / Anthropic Messages API.
enum ChatRole { user, assistant }

/// A single chat message in the transcript.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.offline = false,
  }) : timestamp = timestamp ?? DateTime.now();

  final ChatRole role;
  final String content;
  final DateTime timestamp;

  /// True when this assistant reply came from the local offline reference
  /// (no API key configured) rather than a live model call.
  final bool offline;

  bool get isUser => role == ChatRole.user;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'offline': offline,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
        content: (json['content'] as String?) ?? '',
        timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
            DateTime.now(),
        offline: (json['offline'] as bool?) ?? false,
      );
}

/// A quick-prompt preset that seeds a system role + starter prompt.
class AiPromptPreset {
  const AiPromptPreset({
    required this.label,
    required this.systemRole,
    required this.starterPrompt,
  });

  final String label;
  final String systemRole;
  final String starterPrompt;
}

/// Provider-agnostic AI Flight Assistant service with a real Anthropic Claude
/// adapter. Owns the conversation history and persists it to shared_preferences.
///
/// Swapping providers only requires reimplementing [sendMessage] (and the
/// [configured] check) — the screen depends only on this interface.
class AiService extends ChangeNotifier {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  final List<ChatMessage> _messages = <ChatMessage>[];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _sending = false;
  bool get sending => _sending;

  /// The AmericanGroupLLC backend AI service is the primary "one model" — it's
  /// available whenever the user is signed in (the call is authenticated).
  bool get backendAvailable => AuthService.instance.isAuthenticated;

  /// True when a real model can answer (backend AI when signed in, or a direct
  /// Anthropic key), so the UI can be honest about live-AI vs offline reference.
  bool get configured =>
      backendAvailable || _anthropicApiKey.trim().isNotEmpty;

  /// Which backend answered last, for an honest UI label.
  String _source = 'offline';
  String get source => _source;

  /// Quick-prompt presets covering the requested AI roles.
  static const List<AiPromptPreset> presets = <AiPromptPreset>[
    AiPromptPreset(
      label: 'AI CFI',
      systemRole:
          'You are an experienced FAA Certificated Flight Instructor (CFI). '
          'Explain aviation concepts clearly, cite relevant FARs/AIM sections '
          'when useful, and always emphasize safety. You are a study aid, not '
          'a substitute for a real instructor or official guidance.',
      starterPrompt:
          'Act as my CFI. Explain the four forces of flight and how they '
          'change during a climb.',
    ),
    AiPromptPreset(
      label: 'Weather',
      systemRole:
          'You are an aviation weather specialist. Interpret METARs, TAFs, '
          'PIREPs and forecasts for pilots. Translate raw codes into plain '
          'language and highlight go/no-go considerations. Remind pilots to '
          'use official briefings.',
      starterPrompt:
          'Decode and interpret this METAR: KSFO 121956Z 28012KT 10SM FEW015 '
          'SCT200 19/12 A2992.',
    ),
    AiPromptPreset(
      label: 'NOTAMs',
      systemRole:
          'You are an expert at explaining NOTAMs to pilots. Decode NOTAM '
          'shorthand into plain English and explain the operational impact. '
          'Always advise confirming against an official source.',
      starterPrompt:
          'Explain what a typical runway closure NOTAM contains and how I '
          'should react to it during preflight planning.',
    ),
    AiPromptPreset(
      label: 'Regulations',
      systemRole:
          'You are an FAA regulations assistant. Help pilots find and '
          'understand 14 CFR (FARs) and AIM guidance. Cite the specific part '
          'and section. Note that you are informational only and pilots must '
          'verify against current official regulations.',
      starterPrompt:
          'What are the required documents that must be aboard an aircraft '
          'per the FARs?',
    ),
    AiPromptPreset(
      label: 'Radio',
      systemRole:
          'You are a radio phraseology trainer. Teach correct ATC '
          'communication using standard phraseology per the AIM/Pilot-'
          'Controller Glossary. Give example exchanges and correct common '
          'mistakes.',
      starterPrompt:
          'Walk me through the standard radio calls for departing a '
          'towered airport.',
    ),
    AiPromptPreset(
      label: 'Emergency',
      systemRole:
          'You are an emergency procedures assistant for pilots (training/'
          'review use only). Explain standard emergency procedures and the '
          'aviate-navigate-communicate priority. ALWAYS state that in a real '
          'emergency the pilot must follow the aircraft POH/AFM checklist and '
          'ATC instructions.',
      starterPrompt:
          'Review the general steps for handling an engine failure in a '
          'single-engine airplane.',
    ),
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _messages
          ..clear()
          ..addAll(decoded
              .whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromJson));
        notifyListeners();
      }
    } catch (_) {
      // Corrupt history should never crash the screen — start fresh.
    }
  }

  Future<void> clearHistory() async {
    _messages.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyPrefsKey);
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  /// Send [prompt] and return the assistant reply text. Appends both the user
  /// message and the assistant reply to the transcript and persists it.
  ///
  /// Provider-agnostic entry point: [systemRole] seeds the system prompt.
  Future<String> sendMessage(String prompt, {String? systemRole}) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return '';

    _messages.add(ChatMessage(role: ChatRole.user, content: trimmed));
    _sending = true;
    notifyListeners();

    String reply;
    bool offline;
    try {
      if (backendAvailable) {
        // Primary: the single backend AI model (authenticated /ai/chat).
        reply = await _callBackendAi(trimmed, systemRole: systemRole);
        offline = false;
        _source = 'backend';
      } else if (_anthropicApiKey.trim().isNotEmpty) {
        reply = await _callAnthropic(trimmed, systemRole: systemRole);
        offline = false;
        _source = 'anthropic';
      } else {
        reply = _offlineReply(trimmed);
        offline = true;
        _source = 'offline';
      }
    } catch (e) {
      reply = _friendlyError(e);
      offline = true;
      _source = 'offline';
    }

    _messages.add(ChatMessage(
      role: ChatRole.assistant,
      content: reply,
      offline: offline,
    ));
    _sending = false;
    notifyListeners();
    await _persist();
    return reply;
  }

  // ── AmericanGroupLLC backend AI adapter (primary model) ─────────────────────

  /// Calls the backend AI service (POST /ai/chat) with the signed-in user's
  /// bearer token. This is the single shared "model to help" for the app.
  Future<String> _callBackendAi(String prompt, {String? systemRole}) async {
    final token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty) {
      // Shouldn't happen (guarded by backendAvailable), but stay honest.
      return _offlineReply(prompt);
    }

    // The guide documents the body as { message, context }. We pass the role
    // as context so the server can specialize the aviation assistant.
    final body = <String, dynamic>{
      'message': prompt,
      'context': (systemRole != null && systemRole.trim().isNotEmpty)
          ? systemRole.trim()
          : 'aviation',
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${BackendConfig.apiBaseUrl}${BackendConfig.aiChatPath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_httpTimeout);
    } on TimeoutException {
      return 'The AI request timed out. Please check your connection and try '
          'again.';
    } catch (_) {
      return 'Could not reach the AI service. Please check your internet '
          'connection and try again.';
    }

    if (response.statusCode == 401) {
      // Token likely expired — try one refresh, then retry once.
      final refreshed = await AuthService.instance.refresh();
      if (refreshed) return _callBackendAi(prompt, systemRole: systemRole);
      return 'Your session expired. Please sign in again to use the AI '
          'assistant.';
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      return _httpErrorMessage(response.statusCode);
    }

    try {
      final decoded = jsonDecode(response.body);
      final text = _extractBackendReply(decoded);
      if (text != null && text.trim().isNotEmpty) return text.trim();
      return 'The AI returned an empty response. Please try rephrasing your '
          'question.';
    } catch (_) {
      return 'The AI returned an unexpected response. Please try again.';
    }
  }

  /// Defensively pull the reply text out of the backend's JSON, since the exact
  /// field name isn't fixed by the guide.
  String? _extractBackendReply(dynamic decoded) {
    if (decoded is String) return decoded;
    if (decoded is Map) {
      for (final key in const [
        'reply',
        'response',
        'message',
        'answer',
        'text',
        'content',
        'result',
        'output',
      ]) {
        final v = decoded[key];
        if (v is String && v.trim().isNotEmpty) return v;
        if (v is Map) {
          final nested = _extractBackendReply(v);
          if (nested != null) return nested;
        }
        if (v is List && v.isNotEmpty) {
          final first = v.first;
          if (first is String) return first;
          if (first is Map && first['text'] is String) {
            return first['text'] as String;
          }
        }
      }
      // Some APIs wrap under `data`.
      if (decoded['data'] != null) return _extractBackendReply(decoded['data']);
    }
    return null;
  }

  // ── Anthropic Claude adapter ────────────────────────────────────────────────

  Future<String> _callAnthropic(String prompt, {String? systemRole}) async {
    // Send the full conversation history for multi-turn context.
    final apiMessages = <Map<String, dynamic>>[];
    for (final m in _messages) {
      apiMessages.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      });
    }

    final body = <String, dynamic>{
      'model': _anthropicModel,
      'max_tokens': _maxTokens,
      if (systemRole != null && systemRole.trim().isNotEmpty)
        'system': systemRole.trim(),
      'messages': apiMessages,
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_anthropicEndpoint),
            headers: const {
              'x-api-key': _anthropicApiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_httpTimeout);
    } on TimeoutException {
      return 'The AI request timed out after 30 seconds. Please check your '
          'connection and try again.';
    } catch (_) {
      return 'Could not reach the AI service. Please check your internet '
          'connection and try again.';
    }

    if (response.statusCode != 200) {
      return _httpErrorMessage(response.statusCode);
    }

    try {
      final decoded = jsonDecode(response.body);
      final content = (decoded is Map) ? decoded['content'] : null;
      if (content is List && content.isNotEmpty) {
        final first = content.first;
        if (first is Map && first['text'] is String) {
          final text = (first['text'] as String).trim();
          if (text.isNotEmpty) return text;
        }
      }
      return 'The AI returned an empty response. Please try rephrasing your '
          'question.';
    } catch (_) {
      return 'The AI returned an unexpected response. Please try again.';
    }
  }

  String _httpErrorMessage(int status) {
    switch (status) {
      case 401:
        return 'The AI request was not authorized (401). Please verify the '
            'ANTHROPIC_API_KEY value.';
      case 429:
        return 'The AI service is rate limited (429). Please wait a moment and '
            'try again.';
      case 500:
      case 502:
      case 503:
      case 529:
        return 'The AI service is temporarily unavailable ($status). Please '
            'try again shortly.';
      default:
        return 'The AI service returned an error (HTTP $status). Please try '
            'again.';
    }
  }

  String _friendlyError(Object error) =>
      'Something went wrong contacting the AI service. Please try again.\n\n'
      '_(${error.runtimeType})_';

  // ── Offline reference (no AI key configured) ────────────────────────────────

  /// Small local rules/FAQ map so the screen stays useful and truthful when
  /// no API key is present.
  static const Map<String, String> _faq = <String, String>{
    'weather': '**Reading a METAR (quick guide)**\n'
        '- `KSFO` station, `121956Z` day 12 at 19:56 UTC\n'
        '- `28012KT` wind 280° at 12 kt\n'
        '- `10SM` visibility 10 statute miles\n'
        '- `FEW015 SCT200` clouds (few @ 1,500 ft, scattered @ 20,000 ft)\n'
        '- `19/12` temp 19°C / dewpoint 12°C\n'
        '- `A2992` altimeter 29.92 inHg\n\n'
        'Compare against personal minimums and always get an official '
        'preflight briefing (1800wxbrief.com / ForeFlight).',
    'checklist': '**Generic preflight flow**\n'
        '1. Documents (AROW): Airworthiness, Registration, Operating '
        'limitations, Weight & balance\n'
        '2. Exterior walkaround: control surfaces, fuel/oil, tires, '
        'pitot-static\n'
        '3. Cabin: seats/belts, controls free & correct\n'
        '4. Before start / start / runup per the POH\n\n'
        'Always use your specific aircraft POH/AFM checklist — this is only a '
        'reminder of the general flow.',
    'regulation': '**Required documents aboard (ARROW)**\n'
        '- **A**irworthiness certificate\n'
        '- **R**egistration certificate\n'
        '- **R**adio station license (international ops)\n'
        '- **O**perating limitations (POH/AFM, placards, markings)\n'
        '- **W**eight & balance data\n\n'
        'See 14 CFR 91.9 and 91.203. Verify against current official '
        'regulations — this is informational only.',
    'radio': '**Standard departure call (towered field)**\n'
        '1. Ground: "Ground, N12345 at the ramp, taxi with information '
        'Bravo."\n'
        '2. Tower (holding short): "Tower, N12345 holding short runway 28, '
        'ready for departure."\n'
        '3. After takeoff, follow tower instructions for frequency change.\n\n'
        'Use the AIM Pilot/Controller Glossary for standard phraseology.',
    'emergency': '**Engine failure priorities: Aviate – Navigate – '
        'Communicate**\n'
        '1. **Aviate:** pitch for best glide speed.\n'
        '2. **Navigate:** pick the best landing site into the wind.\n'
        '3. Run the engine-failure checklist (fuel, mixture, mags, '
        'carb heat).\n'
        '4. **Communicate:** squawk 7700, call on 121.5 if unresolved.\n\n'
        'In a real emergency, follow your aircraft POH/AFM checklist and ATC '
        'instructions — this is review material only.',
    'notam': '**NOTAMs** report temporary changes to the airspace/airport '
        'system (closures, unserviceable equipment, obstacles, TFRs). '
        'Decode the location, affected facility, and the effective time '
        'window, then plan around it. Always confirm against an official '
        'NOTAM source during preflight.',
  };

  String _offlineReply(String prompt) {
    final lower = prompt.toLowerCase();
    String? body;

    if (lower.contains('metar') ||
        lower.contains('taf') ||
        lower.contains('weather') ||
        lower.contains('wx')) {
      body = _faq['weather'];
    } else if (lower.contains('checklist') ||
        lower.contains('preflight') ||
        lower.contains('walkaround')) {
      body = _faq['checklist'];
    } else if (lower.contains('notam')) {
      body = _faq['notam'];
    } else if (lower.contains('regulation') ||
        lower.contains('far') ||
        lower.contains('document') ||
        lower.contains('14 cfr') ||
        lower.contains('cfr')) {
      body = _faq['regulation'];
    } else if (lower.contains('radio') ||
        lower.contains('phraseology') ||
        lower.contains('atc') ||
        lower.contains('call')) {
      body = _faq['radio'];
    } else if (lower.contains('emergency') ||
        lower.contains('engine failure') ||
        lower.contains('mayday')) {
      body = _faq['emergency'];
    }

    body ??= 'I can offer static aviation reference on these topics offline:\n'
        '- Weather interpretation (METAR/TAF)\n'
        '- Preflight checklist flow\n'
        '- NOTAM explanation\n'
        '- Regulation lookup (required documents)\n'
        '- Radio phraseology\n'
        '- Emergency procedures\n\n'
        'Ask about one of these, or add an API key for full AI answers.';

    return '**Offline reference (not signed in)**\n\n'
        'Sign in to your AmericanGroupLLC account to use the live AI assistant. '
        '(A direct Anthropic key via `--dart-define=ANTHROPIC_API_KEY=...` also '
        'works for development.)\n\n'
        '$body';
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(_messages.map((m) => m.toJson()).toList(growable: false));
      await prefs.setString(_historyPrefsKey, encoded);
    } catch (_) {
      // Persistence failures must never crash the chat.
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
