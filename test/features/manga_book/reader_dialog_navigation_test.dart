import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql/client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/constants/reader_keyboard_shortcuts.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_wrapper.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/graphql/__generated__/schema.graphql.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('reader overlay is hidden by default', (tester) async {
    await _pumpReader(tester, initialPreferences: const {});

    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('reader mode dialog stays in the reader navigator', (
    tester,
  ) async {
    final harness = await _pumpReader(
      tester,
      initialPreferences: const {'readerOverlay': true},
    );

    await tester.tap(find.byIcon(Icons.app_settings_alt_outlined));
    await tester.pumpAndSettle();

    expect(harness.rootObserver.dialogPushes, 0);
    expect(harness.readerObserver.dialogPushes, 1);

    await tester.tap(find.byType(RadioListTile<ReaderMode>).at(1));
    await tester.pumpAndSettle();

    expect(harness.readerObserver.dialogPops, 1);
    expect(await harness.readerNavigatorKey.currentState!.maybePop(), isTrue);
  });

  testWidgets('reader navigation layout dialog stays in the reader navigator', (
    tester,
  ) async {
    final harness = await _pumpReader(
      tester,
      initialPreferences: const {'readerOverlay': true},
    );

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.touch_app_rounded));
    await tester.pumpAndSettle();

    expect(harness.rootObserver.dialogPushes, 0);
    expect(harness.readerObserver.dialogPushes, 1);

    await tester.tap(
      find.byType(RadioListTile<ReaderNavigationLayout>).at(1),
    );
    await tester.pumpAndSettle();

    expect(harness.readerObserver.dialogPops, 1);
    expect(await harness.readerNavigatorKey.currentState!.maybePop(), isTrue);
  });

  testWidgets('chapter replacement preserves the hidden reader overlay', (
    tester,
  ) async {
    final harness = await _pumpReader(
      tester,
      initialPreferences: const {'readerOverlay': true},
    );

    expect(find.byType(AppBar), findsOneWidget);

    Actions.invoke(
      tester.element(find.byType(ReaderView)),
      HideQuickOpenIntent(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);

    harness.readerNavigatorKey.currentState!.pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => _readerWrapper(_nextChapter),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);

    expect(await harness.readerNavigatorKey.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();

    harness.readerNavigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(builder: (_) => _readerWrapper(_chapter)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
  });
}

Future<_ReaderHarness> _pumpReader(
  WidgetTester tester, {
  Map<String, Object> initialPreferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final preferences = await SharedPreferences.getInstance();
  final rootObserver = _DialogObserver();
  final readerObserver = _DialogObserver();
  final readerNavigatorKey = GlobalKey<NavigatorState>();
  final repository = MangaBookRepository(
    GraphQLClient(
      link: Link.function(
        (_, [__]) => Stream.value(const Response(response: {})),
      ),
      cache: GraphQLCache(),
    ),
  );
  final router = GoRouter(
    observers: [rootObserver],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Navigator(
          key: readerNavigatorKey,
          initialRoute: '/manga/1/chapter/1',
          observers: [readerObserver],
          onGenerateInitialRoutes: (navigator, initialRoute) => [
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/manga/1'),
              builder: (_) => const SizedBox(),
            ),
            MaterialPageRoute<void>(
              settings: RouteSettings(name: initialRoute),
              builder: (_) => _readerWrapper(_chapter),
            ),
          ],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        mangaBookRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _ReaderHarness(
    rootObserver: rootObserver,
    readerObserver: readerObserver,
    readerNavigatorKey: readerNavigatorKey,
  );
}

ReaderWrapper _readerWrapper(Fragment$ChapterDto chapter) => ReaderWrapper(
      manga: _manga,
      chapter: chapter,
      chapterPages: _chapterPages,
      currentIndex: 0,
      onChanged: (_) {},
      onNext: () {},
      onPrevious: () {},
      scrollDirection: Axis.horizontal,
      child: const SizedBox.expand(
        key: ValueKey('reader-page'),
        child: ColoredBox(color: Colors.black),
      ),
    );

final _manga = Fragment$MangaDto(
  downloadCount: 0,
  genre: const [],
  id: 1,
  inLibrary: false,
  inLibraryAt: '0',
  initialized: true,
  meta: const [],
  sourceId: '1',
  status: Enum$MangaStatus.UNKNOWN,
  title: 'Manga',
  unreadCount: 1,
  updateStrategy: Enum$UpdateStrategy.ALWAYS_UPDATE,
  url: '',
);

final _chapter = Fragment$ChapterDto(
  chapterNumber: 1,
  fetchedAt: '0',
  id: 1,
  isBookmarked: false,
  isDownloaded: false,
  isRead: false,
  lastPageRead: 0,
  lastReadAt: '0',
  mangaId: 1,
  name: 'Chapter 1',
  pageCount: 1,
  sourceOrder: 1,
  uploadDate: '0',
  url: '',
  meta: const [],
);

final _nextChapter = Fragment$ChapterDto(
  chapterNumber: 2,
  fetchedAt: '0',
  id: 2,
  isBookmarked: false,
  isDownloaded: false,
  isRead: false,
  lastPageRead: 0,
  lastReadAt: '0',
  mangaId: 1,
  name: 'Chapter 2',
  pageCount: 1,
  sourceOrder: 2,
  uploadDate: '0',
  url: '',
  meta: const [],
);

final _chapterPages = Fragment$ChapterPagesDto(
  chapter: Fragment$ChapterPagesDto$chapter(id: 1, pageCount: 1),
  pages: const ['page'],
);

class _ReaderHarness {
  const _ReaderHarness({
    required this.rootObserver,
    required this.readerObserver,
    required this.readerNavigatorKey,
  });

  final _DialogObserver rootObserver;
  final _DialogObserver readerObserver;
  final GlobalKey<NavigatorState> readerNavigatorKey;
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
