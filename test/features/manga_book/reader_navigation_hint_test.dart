import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql/client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/db_keys.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/chapter_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/manga_details/controller/manga_details_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/reader_screen.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_navigation_layout/layouts/l_shaped_layout.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_navigation_layout/layouts/right_and_left_layout.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_navigation_layout/reader_navigation_layout.dart';
import 'package:tachidesk_sorayomi/src/features/settings/presentation/reader/widgets/reader_navigation_layout_tile/reader_navigation_layout_tile.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/graphql/__generated__/schema.graphql.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/routes/router_config.dart';

void main() {
  for (final mangaMode in [
    null,
    ReaderMode.defaultReader,
    ReaderMode.singleHorizontalLTR,
  ]) {
    testWidgets('only layout changes show hints in the reader: $mangaMode',
        (tester) async {
      final router = await _pumpReader(tester, mangaMode);
      expect(find.byType(LShapedLayout), findsOneWidget);
      expect(_visibleHintColors(tester), isEmpty,
          reason: 'Opening a reader must not show hints');
      await _finishTransition(tester);

      await _selectLayout(tester, ReaderNavigationLayout.rightAndLeft);
      expect(find.byType(RightAndLeftLayout), findsOneWidget);
      expect(_visibleHintColors(tester), isNotEmpty,
          reason: 'Saving a different layout must show its hint');
      await tester.pump(const Duration(seconds: 2));
      expect(_visibleHintColors(tester), isEmpty);

      await _selectLayout(tester, ReaderNavigationLayout.rightAndLeft);
      expect(_visibleHintColors(tester), isEmpty,
          reason: 'Selecting the current layout must not replay hints');
      // Selecting the checked radio leaves the dialog open.
      router.pop();
      await _finishTransition(tester);

      await _selectLayout(tester, ReaderNavigationLayout.defaultNavigation);
      expect(find.byType(LShapedLayout), findsOneWidget);
      expect(_visibleHintColors(tester), isNotEmpty,
          reason: 'Returning to a different global layout must show its hint');

      router.pushReplacement('/reader/2?next=true');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LShapedLayout), findsOneWidget);
      expect(_visibleHintColors(tester), isEmpty,
          reason: 'Changing chapter must not restart or carry over hints');
      await _finishTransition(tester);

      router.pop();
      await _finishTransition(tester);
      router.push('/reader/1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LShapedLayout), findsOneWidget);
      expect(_visibleHintColors(tester), isEmpty,
          reason: 'Reopening a reader must not show hints');
      await _finishTransition(tester);
    });
  }

  testWidgets('global changes show hints only when the manga follows them',
      (tester) async {
    await _pumpReader(tester, ReaderMode.defaultReader);
    await _finishTransition(tester);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ReaderScreen)));
    final globalLayout =
        container.read(readerNavigationLayoutKeyProvider.notifier);
    globalLayout.update(ReaderNavigationLayout.rightAndLeft);
    await tester.pump();
    expect(find.byType(RightAndLeftLayout), findsOneWidget);
    expect(_visibleHintColors(tester), isNotEmpty);

    globalLayout.update(ReaderNavigationLayout.disabled);
    await tester.pump();
    expect(_visibleHintColors(tester), isEmpty,
        reason: 'Disabling a layout must immediately remove the hint');

    await _selectLayout(tester, ReaderNavigationLayout.lShaped);
    expect(_visibleHintColors(tester), isNotEmpty);
    await tester.pump(const Duration(seconds: 2));
    globalLayout.update(ReaderNavigationLayout.edge);
    await tester.pump();
    expect(find.byType(LShapedLayout), findsOneWidget);
    expect(_visibleHintColors(tester), isEmpty,
        reason: 'A global change must not replay an overridden manga layout');
  });
}

Iterable<Color> _visibleHintColors(WidgetTester tester) => tester
    .widgetList<ColoredBox>(find.descendant(
      of: find.byType(ReaderNavigationLayoutWidget),
      matching: find.byType(ColoredBox),
    ))
    .map((box) => box.color)
    .where((color) => color.a > 0);

Future<void> _finishTransition(WidgetTester tester) async {
  // The real reader's image placeholder keeps animating without a server.
  // Advance the route/drawer transition without waiting for image loading.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _selectLayout(
    WidgetTester tester, ReaderNavigationLayout layout) async {
  if (find.byType(AppBar).evaluate().isEmpty) {
    await tester.tapAt(const Offset(400, 300));
    await _finishTransition(tester);
  }
  await tester.tap(find.byIcon(Icons.settings_rounded));
  await _finishTransition(tester);
  await tester.tap(find.byIcon(Icons.touch_app_rounded));
  await _finishTransition(tester);
  await tester.tap(find.byWidgetPredicate((widget) =>
      widget is RadioListTile<ReaderNavigationLayout> &&
      widget.value == layout));
  await _finishTransition(tester);
}

Future<GoRouter> _pumpReader(WidgetTester tester, ReaderMode? mangaMode) async {
  SharedPreferences.setMockInitialValues({
    DBKeys.readerMode.name: ReaderMode.singleHorizontalLTR.index,
    DBKeys.readerNavigationLayout.name: ReaderNavigationLayout.lShaped.index,
  });
  final preferences = await SharedPreferences.getInstance();
  final router = GoRouter(routes: [
    GoRoute(
        path: '/', builder: (_, __) => const Scaffold(body: Text('Details'))),
    GoRoute(
      path: '/reader/:chapterId',
      pageBuilder: (context, state) => ReaderRoute(
        mangaId: 1,
        chapterId: int.parse(state.pathParameters['chapterId']!),
        startAtBeginning: state.uri.queryParameters['next'] == 'true',
      ).buildPage(context, state),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      mangaBookRepositoryProvider.overrideWithValue(_Repository(mangaMode)),
      for (final id in [1, 2])
        getNextAndPreviousChaptersProvider(mangaId: 1, chapterId: id)
            .overrideWith((_) => null),
    ],
    child: MaterialApp.router(
      theme: ThemeData(platform: TargetPlatform.iOS),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  router.push('/reader/1');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return router;
}

class _Repository extends MangaBookRepository {
  _Repository(this.mangaMode)
      : super(GraphQLClient(
            link: Link.function((_, [__]) => const Stream<Response>.empty()),
            cache: GraphQLCache()));

  final ReaderMode? mangaMode;
  ReaderNavigationLayout layout = ReaderNavigationLayout.defaultNavigation;

  @override
  Future<void> patchMangaMeta(
      {required int mangaId,
      required String key,
      required dynamic value}) async {
    if (key == 'flutter_readerNavigationLayout') {
      layout = ReaderNavigationLayout.values.byName(value as String);
    }
  }

  @override
  Future<Fragment$MangaDto?> getManga({required int mangaId}) async =>
      Fragment$MangaDto(
        downloadCount: 0,
        genre: const [],
        id: 1,
        inLibrary: false,
        inLibraryAt: '0',
        initialized: true,
        meta: [
          Fragment$MangaDto$meta(
            key: 'flutter_readerNavigationLayout',
            value: layout.name,
          ),
          if (mangaMode != null)
            Fragment$MangaDto$meta(
              key: 'flutter_readerMode',
              value: mangaMode!.name,
            ),
        ],
        sourceId: '1',
        status: Enum$MangaStatus.UNKNOWN,
        title: 'Manga',
        unreadCount: 1,
        updateStrategy: Enum$UpdateStrategy.ALWAYS_UPDATE,
        url: '',
      );

  @override
  Future<ChapterDto?> getChapter({required int chapterId}) async => ChapterDto(
        chapterNumber: 1,
        fetchedAt: '0',
        id: chapterId,
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

  @override
  Future<Fragment$ChapterPagesDto?> getChapterPages(
          {required int chapterId}) async =>
      Fragment$ChapterPagesDto(
        chapter: Fragment$ChapterPagesDto$chapter(id: chapterId, pageCount: 1),
        pages: const ['/page-1'],
      );
}
