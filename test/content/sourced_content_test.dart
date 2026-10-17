/// The Learn and Practice content is FAA-sourced, and stays that way: every
/// line has a citation, the generated Dart matches content/*.json, and none
/// of it says "safe".
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/content/faa_library.g.dart';
import 'package:pilot_enroute/content/faa_questions.g.dart';
import 'package:pilot_enroute/content/instruments.g.dart';
import 'package:pilot_enroute/content/sourced.dart';

final _cite = RegExp(r'^(PHAK FAA-H-8083-25C, ch\. 8, p\. 8-\d+|AIM \d-\d-\d+)');

void main() {
  test('the generated Dart is up to date with content/*.json', () {
    final r = Process.runSync('python3', ['tools/gen_content.py', '--check']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('all six instruments, each with every section, every line cited', () {
    expect(instrumentLessons.map((l) => l.id).toSet(),
        {'asi', 'ai', 'alt', 'tc', 'hi', 'vsi'});
    for (final l in instrumentLessons) {
      for (final section in [l.shows, l.works, l.read, l.errors]) {
        expect(section, isNotEmpty, reason: l.id);
        for (final line in section) {
          expect(line.cite, matches(_cite), reason: line.text);
        }
      }
    }
  });

  test('pattern, six sign types and markings, every line from the AIM', () {
    expect(airportSigns, hasLength(6));
    final all = <SourcedLine>[
      ...trafficPattern,
      ...airportMarkings,
      for (final s in airportSigns) s.meaning,
    ];
    for (final line in all) {
      expect(line.cite, startsWith('AIM '), reason: line.text);
    }
  });

  test('nothing in the Learn or Practice content says "safe"', () {
    final texts = <String>[
      for (final l in instrumentLessons)
        for (final s in [...l.shows, ...l.works, ...l.read, ...l.errors]) s.text,
      for (final l in [...trafficPattern, ...airportMarkings]) l.text,
      for (final s in airportSigns) s.meaning.text,
      for (final q in faaSampleQuestions) q.explanation,
    ];
    for (final t in texts) {
      expect(t.toLowerCase(), isNot(contains('safe')), reason: t);
    }
  });

  test('the library is the FAA\'s own documents, on faa.gov or ecfr.gov', () {
    expect(faaLibrary.map((b) => b.docNumber),
        containsAll(['FAA-H-8083-25C', 'FAA-H-8083-3C', 'AIM', 'FAA-S-ACS-6C']));
    for (final b in faaLibrary) {
      final host = Uri.parse(b.url).host;
      expect(host, anyOf('www.faa.gov', 'www.ecfr.gov', 'aeronav.faa.gov'),
          reason: b.url);
      for (final c in b.chapters) {
        expect(Uri.parse(c.url).host, 'www.faa.gov', reason: c.url);
      }
    }
    final phak = faaLibrary.firstWhere((b) => b.id == 'phak');
    expect(phak.chapters.where((c) => int.tryParse(c.n) != null),
        hasLength(17));
  });

  group('knowledge-test bank', () {
    final source = jsonDecode(
            File('content/par_sample_questions.json').readAsStringSync())
        as Map<String, dynamic>;
    final faa = {
      for (final q in source['questions'] as List) q['id'] as String: q
    };

    test('only FAA sample questions, stems and choices word for word', () {
      expect(faaSampleQuestions, isNotEmpty);
      for (final q in faaSampleQuestions) {
        final f = faa[q.id];
        expect(f, isNotNull, reason: q.id);
        expect(q.stem, f['stem'], reason: q.id);
        expect(q.choices, [f['choices']['A'], f['choices']['B'], f['choices']['C']],
            reason: q.id);
        expect(q.acsCode, f['faaRef']['acsCode'], reason: q.id);
      }
    });

    test('no question needs a figure the app does not show', () {
      for (final q in faaSampleQuestions) {
        expect(faa[q.id]['figure'], isNull, reason: q.id);
        expect(faa[q.id]['inlineImage'], anyOf(isNull, isFalse), reason: q.id);
      }
    });

    test('every answer is decided by a quoted, cited FAA source', () {
      for (final q in faaSampleQuestions) {
        expect(q.answer, inInclusiveRange(0, 2), reason: q.id);
        expect(q.quote.length, greaterThan(20), reason: q.id);
        expect(
            q.cite,
            matches(RegExp(r'^(14 CFR|AIM|PHAK|Airplane Flying Handbook|'
                r'Aviation Weather Handbook)')),
            reason: q.id);
        expect(q.explanation, isNotEmpty, reason: q.id);
      }
    });

    test('ids are unique', () {
      final ids = faaSampleQuestions.map((q) => q.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });
}
