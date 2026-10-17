import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../content/faa_library.g.dart';
import '../content/sourced.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The FAA's own handbooks, the AIM, the ACS and 14 CFR, opened from faa.gov
/// / ecfr.gov. The PHAK and the Airplane Flying Handbook also open chapter by
/// chapter.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.opener});

  /// Injected in tests; opens [url] outside the app.
  final Future<bool> Function(Uri url)? opener;

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    var ok = false;
    try {
      ok = await (opener ??
          (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not open ${uri.host}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: const PageTitle('FAA library',
            subtitle: 'Official documents, free from faa.gov'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final b in faaLibrary) ...[
            b.chapters.isEmpty ? _book(context, b) : _bookWithChapters(context, b),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Text(
              'Each opens the edition listed, from the FAA, in your browser or '
              'PDF reader. These were the current editions on faa.gov on 17 '
              'Oct 2026; the FAA revises them, so check for a newer one.',
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _meta(LibraryBook b) => [
        if (b.docNumber.isNotEmpty) b.docNumber,
        if (b.edition.isNotEmpty) b.edition,
        if (b.pages != null) '${b.pages} pages',
        if (!b.pdf) 'web',
      ].join(' · ');

  Widget _book(BuildContext context, LibraryBook b) => NavRowCard(
        key: Key('library-${b.id}'),
        icon: b.pdf ? Icons.picture_as_pdf_outlined : Icons.public,
        title: b.title,
        subtitle: _meta(b),
        trailing: Icon(Icons.open_in_new_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () => _open(context, b.url),
      );

  Widget _bookWithChapters(BuildContext context, LibraryBook b) {
    final scheme = Theme.of(context).colorScheme;
    return SkyCard(
      key: Key('library-${b.id}'),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: const IconTile(Icons.menu_book_outlined),
          title: Text(b.title,
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: scheme.onSurface)),
          subtitle: Text(_meta(b),
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          children: [
            ListTile(
              key: Key('library-${b.id}-full'),
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Whole book (one PDF)'),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _open(context, b.url),
            ),
            for (final c in b.chapters)
              ListTile(
                key: Key('library-${b.id}-${c.n}'),
                leading: SizedBox(
                  width: 34,
                  child: Text(int.tryParse(c.n) == null ? '' : c.n,
                      style: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontWeight: FontWeight.w700)),
                ),
                title: Text(c.title),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => _open(context, c.url),
              ),
          ],
        ),
      ),
    );
  }
}
