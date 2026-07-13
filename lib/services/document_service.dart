import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

/// Categories a [PilotDocument] can belong to.
enum DocCategory {
  aircraft('Aircraft'),
  insurance('Insurance'),
  poh('POH'),
  afm('AFM'),
  certificate('Certificate'),
  medical('Medical'),
  checklist('Checklist'),
  other('Other');

  const DocCategory(this.label);

  /// Human-readable label used in the UI and persisted to storage.
  final String label;

  /// Parse a stored label back into an enum, defaulting to [other].
  static DocCategory fromLabel(String? label) {
    return DocCategory.values.firstWhere(
      (c) => c.label == label,
      orElse: () => DocCategory.other,
    );
  }
}

/// A single stored document (image or generated PDF) with metadata.
class PilotDocument {
  final String id;
  final String title;
  final DocCategory category;

  /// Absolute path to the file on disk. Empty on web (files not persisted).
  final String filePath;

  /// Optional absolute path to a thumbnail image.
  final String? thumbnailPath;

  final DateTime addedDate;
  final DateTime? expiryDate;
  final String notes;

  PilotDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.filePath,
    this.thumbnailPath,
    required this.addedDate,
    this.expiryDate,
    this.notes = '',
  });

  /// True when the file is a PDF (based on its extension).
  bool get isPdf => filePath.toLowerCase().endsWith('.pdf');

  /// True when the file is an image (based on its extension).
  bool get isImage {
    final p = filePath.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp') ||
        p.endsWith('.heic') ||
        p.endsWith('.gif');
  }

  /// Days until [expiryDate], or null when there is no expiry.
  int? get daysUntilExpiry {
    final e = expiryDate;
    if (e == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(e.year, e.month, e.day);
    return target.difference(today).inDays;
  }

  /// True when the document expires within the next 30 days (or is expired).
  bool get isExpiringSoon {
    final d = daysUntilExpiry;
    return d != null && d <= 30;
  }

  /// True when the expiry date has already passed.
  bool get isExpired {
    final d = daysUntilExpiry;
    return d != null && d < 0;
  }

  PilotDocument copyWith({
    String? title,
    DocCategory? category,
    String? filePath,
    String? thumbnailPath,
    DateTime? addedDate,
    DateTime? expiryDate,
    bool clearExpiry = false,
    String? notes,
  }) {
    return PilotDocument(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      addedDate: addedDate ?? this.addedDate,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.label,
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'addedDate': addedDate.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'notes': notes,
      };

  factory PilotDocument.fromJson(Map<String, dynamic> json) => PilotDocument(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Untitled',
        category: DocCategory.fromLabel(json['category'] as String?),
        filePath: json['filePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String?,
        addedDate: DateTime.tryParse(json['addedDate'] as String? ?? '') ??
            DateTime.now(),
        expiryDate: (json['expiryDate'] as String?) != null
            ? DateTime.tryParse(json['expiryDate'] as String)
            : null,
        notes: json['notes'] as String? ?? '',
      );
}

/// Offline-first store for pilot/aircraft documents.
///
/// Files are copied into the app documents directory (`documents/` subfolder)
/// and metadata is persisted to [SharedPreferences] as JSON under
/// [_prefsKey]. All disk access is guarded for web with [kIsWeb].
class DocumentService extends ChangeNotifier {
  static const String _prefsKey = 'pilot_documents';
  static const String _subDir = 'documents';

  final ImagePicker _picker = ImagePicker();

  List<PilotDocument> _documents = [];
  bool _isLoading = false;
  bool _initialized = false;

  List<PilotDocument> get documents => List.unmodifiable(_documents);
  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;

  /// Documents sorted by soonest expiry that fall within 30 days.
  List<PilotDocument> get expiringSoon {
    final list = _documents.where((d) => d.isExpiringSoon).toList()
      ..sort((a, b) =>
          (a.daysUntilExpiry ?? 0).compareTo(b.daysUntilExpiry ?? 0));
    return list;
  }

  /// Return documents for a given [category], or all when null.
  List<PilotDocument> forCategory(DocCategory? category) {
    if (category == null) return documents;
    return _documents.where((d) => d.category == category).toList();
  }

  /// Count of documents in each category.
  Map<DocCategory, int> get categoryCounts {
    final map = <DocCategory, int>{};
    for (final d in _documents) {
      map[d.category] = (map[d.category] ?? 0) + 1;
    }
    return map;
  }

  /// Load persisted metadata. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _documents = decoded
              .whereType<Map<String, dynamic>>()
              .map(PilotDocument.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('DocumentService.init failed: $e');
      _documents = [];
    }
    _sort();
    _initialized = true;
    _isLoading = false;
    notifyListeners();
  }

  void _sort() {
    _documents.sort((a, b) => b.addedDate.compareTo(a.addedDate));
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_documents.map((d) => d.toJson()).toList());
      await prefs.setString(_prefsKey, raw);
    } catch (e) {
      debugPrint('DocumentService._persist failed: $e');
    }
  }

  Future<Directory?> _docsDir() async {
    if (kIsWeb) return null;
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/$_subDir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      debugPrint('DocumentService._docsDir failed: $e');
      return null;
    }
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_documents.length}';

  String _extensionFor(String path) {
    final i = path.lastIndexOf('.');
    if (i == -1 || i == path.length - 1) return 'jpg';
    return path.substring(i + 1).toLowerCase();
  }

  /// Pick an image from [source] (camera or gallery), copy it into the app
  /// documents directory, and add it as a document.
  ///
  /// Returns the created [PilotDocument], or null when cancelled, denied, or
  /// unsupported (e.g. web without a persistent path).
  Future<PilotDocument?> addImageDocument({
    required ImageSource source,
    required String title,
    required DocCategory category,
    DateTime? expiryDate,
    String notes = '',
  }) async {
    if (kIsWeb) {
      debugPrint('DocumentService: image import unsupported on web.');
      return null;
    }
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 85,
      );
    } catch (e) {
      // Permission denied, no camera, etc. Degrade gracefully.
      debugPrint('DocumentService.pickImage failed: $e');
      return null;
    }
    if (picked == null) return null; // user cancelled

    try {
      final dir = await _docsDir();
      if (dir == null) return null;
      final id = _newId();
      final ext = _extensionFor(picked.path);
      final destPath = '${dir.path}/$id.$ext';
      final bytes = await picked.readAsBytes();
      final destFile = File(destPath);
      await destFile.writeAsBytes(bytes, flush: true);

      final doc = PilotDocument(
        id: id,
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        category: category,
        filePath: destPath,
        addedDate: DateTime.now(),
        expiryDate: expiryDate,
        notes: notes.trim(),
      );
      _documents.add(doc);
      _sort();
      await _persist();
      notifyListeners();
      return doc;
    } catch (e) {
      debugPrint('DocumentService.addImageDocument failed: $e');
      return null;
    }
  }

  /// Persist raw [bytes] (e.g. a generated PDF) as a document.
  Future<PilotDocument?> addBytesDocument({
    required Uint8List bytes,
    required String title,
    required DocCategory category,
    String extension = 'pdf',
    DateTime? expiryDate,
    String notes = '',
  }) async {
    if (kIsWeb) {
      debugPrint('DocumentService: file storage unsupported on web.');
      return null;
    }
    try {
      final dir = await _docsDir();
      if (dir == null) return null;
      final id = _newId();
      final destPath = '${dir.path}/$id.$extension';
      await File(destPath).writeAsBytes(bytes, flush: true);

      final doc = PilotDocument(
        id: id,
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        category: category,
        filePath: destPath,
        addedDate: DateTime.now(),
        expiryDate: expiryDate,
        notes: notes.trim(),
      );
      _documents.add(doc);
      _sort();
      await _persist();
      notifyListeners();
      return doc;
    } catch (e) {
      debugPrint('DocumentService.addBytesDocument failed: $e');
      return null;
    }
  }

  // TODO(docs): add file_picker dependency to import arbitrary PDFs/files from
  // the device file system. Currently only image capture/import (via
  // image_picker) and generated PDFs (via pdf+printing) are supported.

  /// Update metadata on an existing document. The underlying file is untouched.
  Future<void> updateMetadata(
    String id, {
    String? title,
    DocCategory? category,
    DateTime? expiryDate,
    bool clearExpiry = false,
    String? notes,
  }) async {
    final idx = _documents.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    _documents[idx] = _documents[idx].copyWith(
      title: title?.trim(),
      category: category,
      expiryDate: expiryDate,
      clearExpiry: clearExpiry,
      notes: notes?.trim(),
    );
    await _persist();
    notifyListeners();
  }

  /// Delete a document: removes both its file (and thumbnail) and metadata.
  Future<void> deleteDocument(String id) async {
    final idx = _documents.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final doc = _documents[idx];
    if (!kIsWeb) {
      await _tryDeleteFile(doc.filePath);
      final thumb = doc.thumbnailPath;
      if (thumb != null) await _tryDeleteFile(thumb);
    }
    _documents.removeAt(idx);
    await _persist();
    notifyListeners();
  }

  Future<void> _tryDeleteFile(String path) async {
    if (kIsWeb || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('DocumentService._tryDeleteFile failed: $e');
    }
  }

  /// Build a sample "Aircraft Document Cover Sheet" PDF, demonstrating the
  /// pdf+printing pipeline. Returns the encoded PDF bytes.
  Future<Uint8List> buildCoverSheetPdf({
    String tailNumber = 'N-REGISTRATION',
    String aircraftType = 'Cessna 172S',
    String operator = 'PilotEnRoute',
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.year}-${_two(now.month)}-${_two(now.day)}';

    const accent = PdfColor.fromInt(0xFF00BCD4);
    const dark = PdfColor.fromInt(0xFF0A1628);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(color: dark),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AIRCRAFT DOCUMENT COVER SHEET',
                      style: pw.TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      operator,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              _pdfRow('Tail Number', tailNumber),
              _pdfRow('Aircraft Type', aircraftType),
              _pdfRow('Generated', dateStr),
              pw.SizedBox(height: 24),
              pw.Text(
                'REQUIRED DOCUMENTS (A.R.R.O.W.)',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                ),
              ),
              pw.SizedBox(height: 8),
              ...const [
                'Airworthiness Certificate',
                'Registration Certificate',
                'Radio Station License (if intl)',
                'Operating Limitations / POH / AFM',
                'Weight & Balance Data',
              ].map(
                (t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 12,
                        height: 12,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: dark),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(t, style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                'Generated by PilotEnRoute · Offline document vault',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
