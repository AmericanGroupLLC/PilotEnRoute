/// Own identity: the hand-built "Clear Skies" palette, the bundled fonts,
/// the 16/12 px radii, no gradients, text+icon status pills.
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
    test('light: sky canvas, navy ink, teal primary, white cards', () {
      final s = buildSkyTheme(Brightness.light).colorScheme;
      expect(s.primary, const Color(0xFF0A7887));
      expect(s.surface, const Color(0xFFF2F7FB));
      expect(s.onSurface, const Color(0xFF0E2235));
      expect(s.surfaceContainerLowest, const Color(0xFFFFFFFF));
      expect(s.tertiary, Sky.go);
    });

    test('dark: night canvas, light ink, bright teal', () {
      final s = buildSkyTheme(Brightness.dark).colorScheme;
      expect(s.surface, const Color(0xFF0B1621));
      expect(s.onSurface, const Color(0xFFE6EEF5));
      expect(s.primary, const Color(0xFF4CC3D0));
    });

    test('text colours meet 4.5:1 on white cards and the canvas', () {
      double contrast(Color a, Color b) {
        final l1 = a.computeLuminance(), l2 = b.computeLuminance();
        return (l1 > l2 ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05));
      }

      for (final c in [
        Sky.ink,
        Sky.muted,
        Sky.teal,
        Sky.go,
        Sky.caution,
        Sky.stop,
      ]) {
        expect(contrast(c, Sky.card), greaterThan(4.5), reason: '$c on card');
        expect(
          contrast(c, Sky.canvas),
          greaterThan(4.5),
          reason: '$c on canvas',
        );
      }
      expect(contrast(Colors.white, Sky.teal), greaterThan(4.5));
    });

    test('status pill text meets 4.5:1 on its own tint, light and dark', () {
      double contrast(Color a, Color b) {
        final l1 = a.computeLuminance(), l2 = b.computeLuminance();
        return (l1 > l2 ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05));
      }

      for (final (ink, tint) in [
        (Sky.go, Sky.goSoft),
        (Sky.caution, Sky.cautionSoft),
        (Sky.stop, Sky.stopSoft),
      ]) {
        expect(contrast(ink, tint), greaterThan(4.5), reason: '$ink on $tint');
      }
      for (final b in [Brightness.light, Brightness.dark]) {
        final theme = buildSkyTheme(b);
        final ctx = theme.colorScheme;
        expect(contrast(ctx.onPrimaryContainer, ctx.primaryContainer),
            greaterThan(4.5), reason: '$b primary container');
      }
    });

    test('the scheme is hand-built, not derived from a seed', () {
      final src = File('lib/ui/theme.dart').readAsStringSync();
      expect(src, isNot(contains('ColorScheme.fromSeed(')));
      expect(src, contains('const ColorScheme skyLightScheme = ColorScheme('));
    });
  });

  group('typography', () {
    test('headings and body Sofia Sans; read-outs Sofia Sans Condensed', () {
      final t = buildSkyTheme(Brightness.light).textTheme;
      expect(t.headlineMedium!.fontFamily, 'SofiaSans');
      expect(t.headlineMedium!.fontWeight, FontWeight.w800);
      expect(t.titleLarge!.fontFamily, 'SofiaSans');
      expect(t.bodyMedium!.fontFamily, 'SofiaSans');
      expect(
        buildSkyTheme(Brightness.light).appBarTheme.titleTextStyle!.fontFamily,
        'SofiaSans',
      );
      expect(AppType.condensed().fontFamily, 'SofiaSansCondensed');
    });

    test('METAR/TAF and numbers use Fira Mono', () {
      expect(AppType.mono().fontFamily, 'FiraMono');
      expect(AppFonts.mono, 'FiraMono');
    });

    test('fonts are bundled, never fetched; Orbitron and Inter are gone', () {
      for (final f
          in Directory('lib')
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
    test('16 px cards, 12 px inputs, pill chips and nav indicator', () {
      final th = buildSkyTheme(Brightness.light);
      final card = th.cardTheme.shape as RoundedRectangleBorder;
      expect(card.borderRadius, BorderRadius.circular(16));
      final input = th.inputDecorationTheme.border as OutlineInputBorder;
      expect(input.borderRadius, BorderRadius.circular(12));
      expect(th.chipTheme.shape, isA<StadiumBorder>());
      expect(th.navigationBarTheme.indicatorShape, isA<StadiumBorder>());
      expect(Sky.radius, 16);
      expect(Sky.radiusM, 12);
    });

    test('no gradients anywhere in lib/', () {
      for (final f
          in Directory('lib')
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
      testWidgets('chip labels are readable on the ${b.name} theme', (
        tester,
      ) async {
        final theme = buildSkyTheme(b);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Wrap(
                children: [
                  ChoiceChip(
                    label: const Text('ASEL'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                  ChoiceChip(
                    label: const Text('AMEL'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
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
          final contrast = (l1 > l2
              ? (l1 + .05) / (l2 + .05)
              : (l2 + .05) / (l1 + .05));
          expect(contrast, greaterThan(4.5), reason: '$label on ${b.name}');
        }
      });
    }
  });

  group('status tags', () {
    testWidgets('every status has a word and an icon, not only a colour', (
      tester,
    ) async {
      for (final s in CheckState.values) {
        final look = lookForCheck(s);
        expect(look.label, isNotEmpty);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSkyTheme(Brightness.light),
            home: Scaffold(body: Center(child: StatusTag(look))),
          ),
        );
        expect(find.text(look.label), findsOneWidget);
        expect(find.byIcon(look.icon), findsOneWidget);
      }
    });

    testWidgets('status pills are capsules with a soft tint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSkyTheme(Brightness.light),
          home: Scaffold(
            body: Center(child: StatusTag(lookForCheck(CheckState.inside))),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(StatusTag),
          matching: find.byType(Container),
        ),
      );
      final deco = box.decoration! as ShapeDecoration;
      expect(deco.shape, isA<StadiumBorder>());
      expect(deco.color, Sky.goSoft);
    });

    test('inside, near and outside never share a tone', () {
      expect({
        lookForCheck(CheckState.inside).tone,
        lookForCheck(CheckState.near).tone,
        lookForCheck(CheckState.outside).tone,
      }, hasLength(3));
    });
  });
}
