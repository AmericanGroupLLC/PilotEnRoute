/// Content types for the Learn tab. Every line carries its FAA citation; the
/// JSON in content/ records the document, edition, URL and file hash each
/// one was taken from.
library;

/// A sentence and where it comes from ("PHAK FAA-H-8083-25C, ch. 8, p. 8-9").
class SourcedLine {
  final String text;
  final String cite;
  const SourcedLine(this.text, this.cite);
}

class SourceDoc {
  final String title;
  final String docNumber;
  final String edition;
  final String url;
  const SourceDoc(this.title, this.docNumber, this.edition, this.url);
}

class InstrumentLesson {
  /// asi · ai · alt · tc · hi · vsi
  final String id;
  final String name;
  final List<SourcedLine> shows;
  final List<SourcedLine> works;
  final List<SourcedLine> read;
  final List<SourcedLine> errors;
  const InstrumentLesson({
    required this.id,
    required this.name,
    required this.shows,
    required this.works,
    required this.read,
    required this.errors,
  });
}

class AirportSign {
  final String type;
  final String colors;
  final SourcedLine meaning;
  const AirportSign(this.type, this.colors, this.meaning);
}

/// An FAA document, checked live on faa.gov / ecfr.gov when the catalogue
/// was built (content/faa_library.json has the date and HTTP status).
class LibraryBook {
  final String id;
  final String title;
  final String docNumber;
  final String edition;
  final String url;
  final bool pdf;
  final int? pages;
  final List<LibraryChapter> chapters;
  const LibraryBook({
    required this.id,
    required this.title,
    required this.docNumber,
    required this.edition,
    required this.url,
    required this.pdf,
    required this.pages,
    required this.chapters,
  });
}

class LibraryChapter {
  /// "1".."17", or "front" / "toc" / "glossary" / "index".
  final String n;
  final String title;
  final String url;
  const LibraryChapter(this.n, this.title, this.url);
}
