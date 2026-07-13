import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/ai_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const Color _bg = Color(0xFF0A1628);
  static const Color _card = Color(0xFF112240);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _amber = Color(0xFFFFB300);
  static const Color _green = Color(0xFF4CAF50);

  final AiService _ai = AiService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // The currently selected role seeds the system prompt for the next send.
  String? _systemRole;

  @override
  void initState() {
    super.initState();
    _ai.addListener(_onServiceChanged);
    _ai.loadHistory().then((_) => _scrollToBottom());
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ai.removeListener(_onServiceChanged);
    _ai.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _ai.sending) return;
    _input.clear();
    _scrollToBottom();
    await _ai.sendMessage(trimmed, systemRole: _systemRole);
    if (!mounted) return;
    _scrollToBottom();
  }

  void _applyPreset(AiPromptPreset preset) {
    setState(() {
      _systemRole = preset.systemRole;
      _input.text = preset.starterPrompt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _ai.messages;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('AI FLIGHT ASSISTANT'),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: messages.isEmpty
                ? null
                : () async {
                    await _ai.clearHistory();
                    if (mounted) setState(() => _systemRole = null);
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          _statusBanner(),
          _presetChips(),
          Expanded(
            child: messages.isEmpty
                ? _emptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _bubble(messages[i]),
                  ),
          ),
          if (_ai.sending) _typingIndicator(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final ready = _ai.configured;
    final color = ready ? _green : _amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(ready ? Icons.check_circle : Icons.info_outline,
              size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ready ? 'AI ready' : 'Offline reference mode — add API key',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: AiService.presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final preset = AiService.presets[i];
          final selected = _systemRole == preset.systemRole;
          return ActionChip(
            backgroundColor: selected
                ? _cyan.withValues(alpha: 0.22)
                : _card,
            side: BorderSide(
              color: selected ? _cyan : Colors.white12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            label: Text(
              preset.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? _cyan : Colors.white70,
              ),
            ),
            onPressed: () => _applyPreset(preset),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy, size: 56, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'Ask your AI Flight Assistant',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pick a role above or type a question about weather, NOTAMs, '
              'regulations, radio work, or emergencies.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage message) {
    final isUser = message.isUser;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser ? _cyan.withValues(alpha: 0.18) : _card;
    final borderColor = isUser ? _cyan.withValues(alpha: 0.4) : Colors.white12;

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.offline)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 13, color: _amber),
                    const SizedBox(width: 5),
                    Text(
                      'Offline reference',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _amber,
                      ),
                    ),
                  ],
                ),
              ),
            if (isUser)
              Text(
                message.content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                ),
              )
            else
              MarkdownBody(
                data: message.content,
                styleSheet: _markdownStyle(),
              ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    final base = GoogleFonts.inter(
      fontSize: 14,
      color: Colors.white,
      height: 1.45,
    );
    return MarkdownStyleSheet(
      p: base,
      listBullet: base,
      strong: base.copyWith(fontWeight: FontWeight.bold, color: _cyan),
      em: base.copyWith(fontStyle: FontStyle.italic, color: Colors.white70),
      h1: GoogleFonts.orbitron(
          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      h2: GoogleFonts.orbitron(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      h3: GoogleFonts.orbitron(
          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      code: GoogleFonts.robotoMono(
        fontSize: 12.5,
        color: _amber,
        backgroundColor: Colors.black26,
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
    );
  }

  Widget _typingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: _cyan),
          ),
          const SizedBox(width: 8),
          Text(
            'Thinking…',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: _card,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask about weather, NOTAMs, regs…',
                  hintStyle:
                      GoogleFonts.inter(fontSize: 13, color: Colors.white38),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cyan),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _ai.sending ? Colors.white12 : _cyan,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _ai.sending ? null : () => _send(_input.text),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send, size: 20, color: Color(0xFF0A1628)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
