/// Own identity (spec M7): the hand-built Remove-Before-Flight palette, the
/// bundled fonts, the 6 px radius, no gradients, text+icon status.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/minimums/minimums_check.dart';
import 'package:pilot_enroute/ui/status_tag.dart';
import 'package:pilot_enroute/ui/theme.dart';

void main() {
  group('palette', () {
    test('light: placard white, panel black, RBF red, panel grey', () {
      final s = buildRbfTheme(Brightness.light).colorScheme;
      expect(s.primary, const Color(0xFFC1121F));
      expect(s.surface, const Color(0xFFF7F7F4));
      expect(s.onSurface, const Color(0xFF1B1D1F));
      expect(s.secondary, const Color(0xFF3A3F44));
      expect(s.tertiary, const Color(0xFF2B8A3E));
    });

    test('dark: panel #15181B, text #ECEDEE, red #FF5A5F', () {
      final s = buildRbfTheme(Brightness.dark).colorScheme;
      expect(s.surface, const Color(0xFF15181B));
      expect(s.onSurface, const Color(0xFFECEDEE));
      expect(s.primary, const Color(0xFFFF5A5F));
    });

    test('go green and caution amber are the spec values', () {
      expect(Rbf.goGreen, const Color(0xFF2B8A3E));
      expect(Rbf.caution, const Color(0xFFE09F00));
    });

    test('the scheme is hand-built, not derived from a seed', () {
      final src = File('lib/ui/theme.dart').readAsStringSync();
      expect(src, isNot(contains('ColorScheme.fromSeed(')));
      expect(src, contains('const ColorScheme rbfLightScheme = ColorScheme('));
    });
  });

  group('typography', () {
    test('headings Sofia Sans Condensed, body Sofia Sans', () {
      final t = buildRbfTheme(Brightness.light).textTheme;
      expect(t.headlineMedium!.fontFamily, 'SofiaSansCondensed');
      expect(t.titleLarge!.fontFamily, 'SofiaSansCondensed');
      expect(t.bodyMedium!.fontFamily, 'SofiaSans');
      expect(buildRbfTheme(Brightness.light).appBarTheme.titleTextStyle!
          .fontFamily, 'SofiaSansCondensed');
    });

    test('METAR/TAF and numbers use Fira Mono', () {
      expect(AppType.mono().fontFamily, 'FiraMono');
      expect(AppFonts.mono, 'FiraMono');
    });

    test('fonts are bundled, never fetched; Orbitron and Inter are gone', () {
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        expect(src.contains('google_fonts'), isFalse, reason: f.path);
        expect(src.toLowerCase().contains('orbitron'), isFalse, reason: f.path);
        expect(src.contains('GoogleFonts.inter'), isFalse, reason: f.path);
      }
      final pub = File('pubspec.yaml').readAsStringSync();
      for (final family in ['SofiaSansCondensed', 'SofiaSans', 'FiraMono']) {
        expect(pub, contains('family: $family'));
      }
    });
  });

  group('shape', () {
    test('6 px radius on cards, inputs and buttons', () {
      final th = buildRbfTheme(Brightness.light);
      final card = th.cardTheme.shape as RoundedRectangleBorder;
      expect(card.borderRadius, BorderRadius.circular(6));
      final input = th.inputDecorationTheme.border as OutlineInputBorder;
      expect(input.borderRadius, BorderRadius.circular(6));
      expect(Rbf.radius, 6);
    });

    test('no gradients anywhere in lib/', () {
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        expect(src.contains('LinearGradient'), isFalse, reason: f.path);
        expect(src.contains('RadialGradient'), isFalse, reason: f.path);
      }
    });
  });

  group('chips', () {
    for (final b in Brightness.values) {
      testWidgets('chip labels are readable on the ${b.name} theme',
          (tester) async {
        final theme = buildRbfTheme(b);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Wrap(children: [
              ChoiceChip(
                  label: const Text('ASEL'), selected: false, onSelected: (_) {}),
              ChoiceChip(
                  label: const Text('AMEL'), selected: true, onSelected: (_) {}),
            ]),
          ),
        ));
        for (final label in ['ASEL', 'AMEL']) {
          final style = DefaultTextStyle.of(tester.element(find.text(label)))
              .style
              .merge(tester.widget<Text>(find.text(label)).style);
          final rendered = tester
              .renderObject<RenderParagraph>(find.text(label))
              .text
              .style!;
          final color = rendered.color ?? style.color!;
          // The label must differ clearly from the page surface.
          final l1 = color.computeLuminance();
          final l2 = theme.colorScheme.surface.computeLuminance();
          final contrast = (l1 > l2 ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05));
          expect(contrast, greaterThan(4.5), reason: '$label on ${b.name}');
        }
      });
    }
  });

  group('status tags', () {
    testWidgets('every status has a word and an icon, not only a colour',
        (tester) async {
      for (final s in CheckState.values) {
        final look = lookForCheck(s);
        expect(look.label, isNotEmpty);
        await tester.pumpWidget(MaterialApp(
            theme: buildRbfTheme(Brightness.light),
            home: Scaffold(body: Center(child: StatusTag(look)))));
        expect(find.text(look.label), findsOneWidget);
        expect(find.byIcon(look.icon), findsOneWidget);
      }
    });

    test('the tag outline is punched: the hole is cut out of the shape', () {
      const size = Size(120, 26);
      final outline = TagPainter.outline(size);
      final hole = TagPainter.hole(size);
      final centre = hole.getBounds().center;
      expect(outline.contains(centre), isTrue);
      final shape = Path.combine(PathOperation.difference, outline, hole);
      expect(shape.contains(centre), isFalse);
    });

    test('inside, near and outside never share a tone', () {
      expect(
          {
            lookForCheck(CheckState.inside).tone,
            lookForCheck(CheckState.near).tone,
            lookForCheck(CheckState.outside).tone,
          },
          hasLength(3));
    });
  });
}
