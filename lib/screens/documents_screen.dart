import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../ui/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../services/document_service.dart';
import 'package:agl_i18n/agl_i18n.dart';

const Color _bg = Color(0xFF15181B);
const Color _card = Color(0xFF1E2226);
const Color _cyan = Color(0xFFFF5A5F);
const Color _amber = Color(0xFFE09F00);
const Color _red = Color(0xFFFF5A5F);
const Color _green = Color(0xFF5CC277);

/// Offline document vault: store aircraft/pilot documents (insurance, POH,
/// AFM, certificates, checklists) as images or generated PDFs.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final DocumentService _service = DocumentService();
  DocCategory? _filter; // null == All
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _service.init();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  IconData _iconFor(DocCategory c) {
    switch (c) {
      case DocCategory.aircraft:
        return Icons.flight;
      case DocCategory.insurance:
        return Icons.shield_outlined;
      case DocCategory.poh:
        return Icons.menu_book;
      case DocCategory.afm:
        return Icons.description;
      case DocCategory.certificate:
        return Icons.workspace_premium;
      case DocCategory.medical:
        return Icons.medical_services_outlined;
      case DocCategory.checklist:
        return Icons.checklist;
      case DocCategory.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _iconColorFor(DocCategory c) {
    switch (c) {
      case DocCategory.aircraft:
        return _cyan;
      case DocCategory.insurance:
        return _green;
      case DocCategory.poh:
        return _amber;
      case DocCategory.afm:
        return const Color(0xFF9C27B0);
      case DocCategory.certificate:
        return _amber;
      case DocCategory.medical:
        return _red;
      case DocCategory.checklist:
        return const Color(0xFF2196F3);
      case DocCategory.other:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = _service.forCategory(_filter);
    final expiring = _service.expiringSoon;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('DOCUMENTS'),
        actions: [
          IconButton(
            tooltip: 'Sample cover sheet',
            icon: const Icon(Icons.picture_as_pdf, color: _cyan),
            onPressed: _busy ? null : _generateSamplePdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cyan,
        foregroundColor: _bg,
        onPressed: _busy ? null : _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(
          'ADD',
          style: AppType.condensed(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _service.isLoading && !_service.isInitialized
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : RefreshIndicator(
              color: _cyan,
              backgroundColor: _card,
              onRefresh: () => _service.init(),
              child: CustomScrollView(
                slivers: [
                  if (kIsWeb) _webBanner(),
                  if (expiring.isNotEmpty) _expiringSection(expiring),
                  _filterChips(),
                  if (docs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    _grid(docs),
                  const SliverToBoxAdapter(child: SizedBox(height: 88)),
                ],
              ),
            ),
    );
  }

  Widget _webBanner() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: _amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'File storage is only available on mobile/desktop. '
                'Documents are not persisted on web.',
                style: AppType.sans(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expiringSection(List<PilotDocument> expiring) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _amber.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: _amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  'EXPIRING SOON',
                  style: AppType.condensed(
                    fontSize: 11,
                    color: _amber,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...expiring.map((d) {
              final days = d.daysUntilExpiry ?? 0;
              final color = d.isExpired || days <= 7 ? _red : _amber;
              final label = d.isExpired
                  ? 'EXPIRED ${(-days)}d ago'
                  : days == 0
                      ? 'EXPIRES TODAY'
                      : 'in ${days}d';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => _openDocument(d),
                  child: Row(
                    children: [
                      Icon(_iconFor(d.category), color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.title,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: AppType.condensed(
                            fontSize: 9,
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    final counts = _service.categoryCounts;
    final chips = <Widget>[
      _chip('ALL', _filter == null, () => setState(() => _filter = null),
          _service.documents.length),
      ...DocCategory.values.map(
        (c) => _chip(
          c.label.toUpperCase(),
          _filter == c,
          () => setState(() => _filter = c),
          counts[c] ?? 0,
        ),
      ),
    ];
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => chips[i],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, int count) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _cyan.withValues(alpha: 0.15) : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _cyan : Colors.white12,
          ),
        ),
        child: Text(
          count > 0 ? '$label · $count' : label,
          style: AppType.condensed(
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
            color: selected ? _cyan : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _grid(List<PilotDocument> docs) {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _docCard(docs[i]),
          childCount: docs.length,
        ),
      ),
    );
  }

  Widget _docCard(PilotDocument d) {
    final iconColor = _iconColorFor(d.category);
    final hasImage = !kIsWeb && d.isImage && File(d.filePath).existsSync();
    return GestureDetector(
      onTap: () => _openDocument(d),
      onLongPress: () => _showDocActions(d),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Image.file(
                      File(d.filePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(d),
                    )
                  else
                    _thumbPlaceholder(d),
                  if (d.isExpiringSoon)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (d.isExpired ? _red : _amber)
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          d.isExpired
                              ? Icons.error_outline
                              : Icons.schedule,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _bg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.category.label.toUpperCase(),
                        style: AppType.condensed(
                          fontSize: 7,
                          color: iconColor,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.expiryDate != null
                        ? 'Exp ${DateFormat.yMMMd().format(d.expiryDate!)}'
                        : 'Added ${DateFormat.yMMMd().format(d.addedDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: 10,
                      color: d.isExpiringSoon
                          ? (d.isExpired ? _red : _amber)
                          : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(PilotDocument d) {
    final color = _iconColorFor(d.category);
    return Container(
      color: _bg,
      alignment: Alignment.center,
      child: Icon(
        d.isPdf ? Icons.picture_as_pdf : _iconFor(d.category),
        color: color,
        size: 42,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            'NO DOCUMENTS',
            style: AppType.condensed(
              fontSize: 14,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _filter == null
                  ? 'Add insurance, POH, AFM, certificates or checklists. '
                      'Everything is stored offline on this device.'
                  : 'No ${_filter!.label} documents yet.',
              textAlign: TextAlign.center,
              style: AppType.sans(fontSize: 13, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _openDocument(PilotDocument d) async {
    if (kIsWeb) {
      _snack('Viewing files is not supported on web.');
      return;
    }
    if (d.isPdf) {
      final file = File(d.filePath);
      if (!file.existsSync()) {
        _snack('File not found.');
        return;
      }
      try {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } catch (e) {
        if (mounted) _snack('Could not open PDF.');
      }
      return;
    }
    if (d.isImage) {
      if (!File(d.filePath).existsSync()) {
        _snack('File not found.');
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ImageViewer(document: d),
        ),
      );
      return;
    }
    _snack('Unsupported document type.');
  }

  void _showDocActions(PilotDocument d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_full, color: _cyan),
              title: Text('Open',
                  style: AppType.sans(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _openDocument(d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: _amber),
              title: Text('Edit details',
                  style: AppType.sans(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditSheet(d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _red),
              title: Text('Delete',
                  style: AppType.sans(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(d);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PilotDocument d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Delete document?',
            style: AppType.condensed(color: Colors.white, fontSize: 14)),
        content: Text(
          'This permanently removes "${d.title}" from this device.',
          style: AppType.sans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.sans(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppType.sans(color: _red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteDocument(d.id);
      if (mounted) _snack('Deleted.');
    }
  }

  void _showAddSheet() {
    if (kIsWeb) {
      _snack('Adding documents is only supported on mobile/desktop.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'ADD DOCUMENT',
                style: AppType.condensed(
                  fontSize: 12,
                  color: _cyan,
                  letterSpacing: 2,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: _cyan),
              title: Text('Capture photo',
                  style: AppType.sans(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _cyan),
              title: Text('Import from gallery',
                  style: AppType.sans(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: _amber),
              title: Text('Generate cover sheet PDF',
                  style: AppType.sans(color: Colors.white)),
              subtitle: Text('Sample aircraft doc, printable',
                  style: AppType.sans(
                      color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _generateSamplePdf(save: true);
              },
            ),
            // Importing arbitrary PDFs would need file_picker — see
            // DocumentService for why it is not a dependency yet.
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addImage(ImageSource source) async {
    // First gather metadata, then pick, then persist.
    final meta = await _showMetadataDialog(
      title: source == ImageSource.camera ? 'Captured Document' : '',
    );
    if (meta == null || !mounted) return;

    setState(() => _busy = true);
    final doc = await _service.addImageDocument(
      source: source,
      title: meta.title,
      category: meta.category,
      expiryDate: meta.expiryDate,
      notes: meta.notes,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (doc == null) {
      _snack('No document added (cancelled or permission denied).');
    } else {
      _snack('Added "${doc.title}".');
    }
  }

  Future<void> _generateSamplePdf({bool save = false}) async {
    setState(() => _busy = true);
    try {
      final bytes = await _service.buildCoverSheetPdf();
      if (!mounted) return;
      if (save) {
        final doc = await _service.addBytesDocument(
          bytes: bytes,
          title: 'Aircraft Cover Sheet',
          category: DocCategory.aircraft,
        );
        if (!mounted) return;
        _snack(doc != null
            ? 'Cover sheet saved to vault.'
            : 'Could not save (unsupported here).');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      }
    } catch (e) {
      if (mounted) _snack('PDF generation failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showEditSheet(PilotDocument d) async {
    final meta = await _showMetadataDialog(
      title: d.title,
      category: d.category,
      expiryDate: d.expiryDate,
      notes: d.notes,
      isEdit: true,
    );
    if (meta == null) return;
    await _service.updateMetadata(
      d.id,
      title: meta.title,
      category: meta.category,
      expiryDate: meta.expiryDate,
      clearExpiry: meta.expiryDate == null,
      notes: meta.notes,
    );
    if (mounted) _snack('Updated.');
  }

  Future<_DocMeta?> _showMetadataDialog({
    String title = '',
    DocCategory category = DocCategory.aircraft,
    DateTime? expiryDate,
    String notes = '',
    bool isEdit = false,
  }) {
    return showDialog<_DocMeta>(
      context: context,
      builder: (ctx) => _MetadataDialog(
        initialTitle: title,
        initialCategory: category,
        initialExpiry: expiryDate,
        initialNotes: notes,
        isEdit: isEdit,
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppType.sans(color: Colors.white)),
        backgroundColor: _card,
      ),
    );
  }
}

/// Result of the metadata dialog.
class _DocMeta {
  final String title;
  final DocCategory category;
  final DateTime? expiryDate;
  final String notes;
  _DocMeta(this.title, this.category, this.expiryDate, this.notes);
}

/// Dialog to collect/edit document metadata (title, category, expiry, notes).
class _MetadataDialog extends StatefulWidget {
  final String initialTitle;
  final DocCategory initialCategory;
  final DateTime? initialExpiry;
  final String initialNotes;
  final bool isEdit;

  const _MetadataDialog({
    required this.initialTitle,
    required this.initialCategory,
    required this.initialExpiry,
    required this.initialNotes,
    required this.isEdit,
  });

  @override
  State<_MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<_MetadataDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late DocCategory _category;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _notesCtrl = TextEditingController(text: widget.initialNotes);
    _category = widget.initialCategory;
    _expiry = widget.initialExpiry;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _cyan,
            surface: _card,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _expiry = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: Text(
        widget.isEdit ? 'EDIT DETAILS' : 'DOCUMENT DETAILS',
        style: AppType.condensed(
            color: _cyan, fontSize: 13, letterSpacing: 1.5),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              style: AppType.sans(color: Colors.white),
              decoration: _inputDeco('Title'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<DocCategory>(
              initialValue: _category,
              dropdownColor: _card,
              isExpanded: true,
              style: AppType.sans(color: Colors.white),
              decoration: _inputDeco('Category'),
              items: DocCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label,
                            style: AppType.sans(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickExpiry,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDeco('Expiry date (optional)'),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Colors.white54, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _expiry != null
                            ? DateFormat.yMMMd().format(_expiry!)
                            : 'None',
                        style: AppType.sans(
                          color:
                              _expiry != null ? Colors.white : Colors.white38,
                        ),
                      ),
                    ),
                    if (_expiry != null)
                      GestureDetector(
                        onTap: () => setState(() => _expiry = null),
                        child: const Icon(Icons.clear,
                            color: Colors.white38, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              style: AppType.sans(color: Colors.white),
              maxLines: 2,
              decoration: _inputDeco('Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text((AglL10n.of(context)?.actionCancel ?? 'Cancel'), style: AppType.sans(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            Navigator.pop(
              context,
              _DocMeta(
                title.isEmpty ? 'Untitled' : title,
                _category,
                _expiry,
                _notesCtrl.text.trim(),
              ),
            );
          },
          child: Text(widget.isEdit ? 'Save' : 'Continue',
              style: AppType.sans(
                  color: _cyan, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppType.sans(color: Colors.white54, fontSize: 13),
      filled: true,
      fillColor: _bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cyan),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
    );
  }
}

/// Full-screen viewer for image documents with pinch-zoom.
class _ImageViewer extends StatelessWidget {
  final PilotDocument document;
  const _ImageViewer({required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          document.title,
          style: AppType.condensed(fontSize: 12, letterSpacing: 1),
        ),
      ),
      body: Center(
        child: kIsWeb
            ? const Text('Not available on web',
                style: TextStyle(color: Colors.white54))
            : InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.file(
                  File(document.filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white24,
                    size: 64,
                  ),
                ),
              ),
      ),
    );
  }
}
