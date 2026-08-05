import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tachidesk_sorayomi/src/features/settings/presentation/general/clear_cache_tile.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpClearCacheTiles(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClearCacheTiles()),
        ),
      ),
    );
  }

  testWidgets('server cache clearing asks for confirmation', (tester) async {
    await pumpClearCacheTiles(tester);

    await tester.tap(find.text('清除服务端缓存'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('清除服务端页面和封面图片缓存'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('client cache clearing asks for confirmation', (tester) async {
    await pumpClearCacheTiles(tester);

    await tester.tap(find.text('清除客户端缓存'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('清除本机磁盘和内存图片缓存'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
