import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/features/settings/presentation/more/more_screen.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/widgets/shell/big_screen_navigation_bar.dart';
import 'package:tachidesk_sorayomi/src/widgets/shell/small_screen_navigation_bar.dart';

void main() {
  testWidgets('primary navigation places browse third and history fourth', (
    tester,
  ) async {
    int? selectedIndex;

    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          bottomNavigationBar: SmallScreenNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    final destinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();

    expect(destinations, ['Library', 'Updates', 'Browse', 'History', 'More']);

    await tester.tap(find.text('History'));
    expect(selectedIndex, 3);
  });

  testWidgets('tablet navigation uses the same destination order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selectedIndex;

    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: Row(
            children: [
              BigScreenNavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (index) => selectedIndex = index,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

    final navigationRail = tester.widget<NavigationRail>(
      find.byType(NavigationRail),
    );
    final destinations = navigationRail.destinations
        .map((destination) => (destination.label as Text).data)
        .toList();

    expect(destinations, ['Library', 'Updates', 'Browse', 'History', 'More']);

    await tester.tap(find.text('History'));
    expect(selectedIndex, 3);
  });

  testWidgets('more screen opens downloads and no longer lists history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/more',
      routes: [
        GoRoute(
          path: '/more',
          builder: (context, state) => const MoreScreen(),
        ),
        GoRoute(
          path: '/downloads',
          builder: (context, state) =>
              const Scaffold(body: Text('Downloads destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: localizedApp(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Downloads'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'History'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Downloads destination'), findsOneWidget);
  });
}

Widget localizedApp({
  Widget? home,
  RouterConfig<Object>? routerConfig,
}) {
  if (routerConfig != null) {
    return MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: routerConfig,
    );
  }

  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
