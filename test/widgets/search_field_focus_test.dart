import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/widgets/search_field.dart';

void main() {
  testWidgets('opening a search result clears focus before returning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const SearchField(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(),
                        body: const Text('Manga details'),
                      ),
                    ),
                  ),
                  child: const Text('Search result'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final focusNode =
        tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Search result'));
    expect(focusNode.hasFocus, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Manga details'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
  });
}
