import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/settings/presentation/reader/widgets/reader_mode_tile/reader_mode_tile.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('reader mode dialog stays in the settings navigator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final rootObserver = _DialogObserver();
    final settingsObserver = _DialogObserver();
    final settingsNavigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          navigatorObservers: [rootObserver],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Navigator(
            key: settingsNavigatorKey,
            initialRoute: '/settings/reader',
            observers: [settingsObserver],
            onGenerateInitialRoutes: (navigator, initialRoute) => [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/settings'),
                builder: (_) => const SizedBox(),
              ),
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/settings/reader'),
                builder: (_) => const Scaffold(body: ReaderModeTile()),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ReaderModeTile));
    await tester.pumpAndSettle();

    expect(rootObserver.dialogPushes, 0);
    expect(settingsObserver.dialogPushes, 1);

    await tester.tap(find.byType(RadioListTile<ReaderMode>).first);
    await tester.pumpAndSettle();

    expect(settingsObserver.dialogPops, 1);
    expect(await settingsNavigatorKey.currentState!.maybePop(), isTrue);
  });
}

class _DialogObserver extends NavigatorObserver {
  int dialogPushes = 0;
  int dialogPops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is DialogRoute) dialogPushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is DialogRoute) dialogPops++;
  }
}
