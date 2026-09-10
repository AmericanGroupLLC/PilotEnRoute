import 'package:agl_i18n/agl_i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The twelve languages this app claims have to actually resolve.
///
/// Declaring a locale the binary cannot serve is how a store listing ends up
/// promising a language the app does not have. This is step one of two: the
/// shared vocabulary is translated here, the app's own copy is not yet — see
/// `l10n_callsites` in the readiness audit for how far that has got.
void main() {
  testWidgets('every standard language resolves through the delegates',
      (tester) async {
    for (final locale in AglLocales.standard) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AglLocales.standard,
          localizationsDelegates: aglLocalizationsDelegates(null),
          home: Builder(
            builder: (context) => Text(AglL10n.of(context)!.actionSave),
          ),
        ),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.byType(Text)).data;
      expect(text, isNotNull, reason: '${locale.languageCode} resolved to null');
      expect(text, isNotEmpty,
          reason: '${locale.languageCode} has an empty shared vocabulary');
    }
  });

  testWidgets('Arabic lays the app out right to left', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AglLocales.standard,
        localizationsDelegates: aglLocalizationsDelegates(null),
        home: Builder(
          builder: (context) => Text(Directionality.of(context).name),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('rtl'), findsOneWidget);
  });

  test('the shared list and this app agree on what is right to left', () {
    expect(AglLocales.isRtl('ar'), isTrue);
    expect(AglLocales.isRtl('en'), isFalse);
  });
}
