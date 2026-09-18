import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/manga_details/controller/manga_details_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_interactive_viewer.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_mode/continuous_reader_mode.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_mode/single_page_reader_mode.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_wrapper.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/graphql/__generated__/schema.graphql.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/widgets/server_image.dart';

void main() {
  testWidgets('paged reader updates its outer state after scrolling settles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'readerOverlay': false,
      'swipeToggle': false,
      'lastPageSwipeEnabled': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final changedPages = <int>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          getNextAndPreviousChaptersProvider(
            mangaId: 1,
            chapterId: 1,
          ).overrideWith((_) => null),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SinglePageReaderMode(
            manga: _manga,
            chapter: _chapter,
            chapterPages: _chapterPages,
            initialPage: 0,
            onPageChanged: changedPages.add,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_readerIndex(tester), 0);
    expect(_serverImage(tester, '/page-1').isAnimationActive, isTrue);
    expect(
      _serverImage(tester, '/page-1').evictFromMemoryOnDispose,
      isTrue,
    );

    final pageView = find.byType(PageView);
    expect(
      find.ancestor(
        of: pageView,
        matching: find.byType(ReaderInteractiveViewer),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: pageView,
        matching: find.byType(ReaderInteractiveViewer),
      ),
      findsWidgets,
    );
    final pageBounds = tester.getRect(pageView);
    final gesture = await tester.startGesture(
      Offset(pageBounds.right - 20, pageBounds.center.dy),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(Offset(-(pageBounds.width * .75), 0));
    await tester.pump();

    expect(
      tester.widget<PageView>(pageView).controller!.page,
      greaterThan(0.5),
    );
    expect(_readerIndex(tester), 0);
    expect(changedPages, isEmpty);
    expect(_serverImage(tester, '/page-1').isAnimationActive, isTrue);
    expect(_serverImage(tester, '/page-2').isAnimationActive, isFalse);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final controller = tester.widget<PageView>(pageView).controller!;
    expect(controller.page, inExclusiveRange(0.5, 1));
    final hold = controller.position.hold(() {});
    await tester.pump();
    expect(_readerIndex(tester), 0,
        reason: 'catching an animation is not a settled page change');
    expect(changedPages, isEmpty);
    hold.cancel();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      tester.widget<PageView>(pageView).controller!.page,
      closeTo(1, .01),
    );
    expect(_readerIndex(tester), 1);
    expect(changedPages, [1]);
    expect(_serverImage(tester, '/page-2').isAnimationActive, isTrue);

    tester.widget<PageView>(pageView).controller!.jumpToPage(0);
    await tester.pump();

    expect(_readerIndex(tester), 0);
    expect(changedPages, [1, 0]);
  });

  testWidgets('continuous reader pauses preloaded page animations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'readerOverlay': true,
      'swipeToggle': false,
      'lastPageSwipeEnabled': false,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          getNextAndPreviousChaptersProvider(
            mangaId: 1,
            chapterId: 1,
          ).overrideWith((_) => null),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ContinuousReaderMode(
            manga: _manga,
            chapter: _chapter,
            chapterPages: _chapterPages,
            initialPage: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_serverImage(tester, '/page-1').isAnimationActive, isTrue);
    expect(_serverImage(tester, '/page-2').isAnimationActive, isFalse);
    expect(
      _serverImage(tester, '/page-1').evictFromMemoryOnDispose,
      isTrue,
    );
    expect(
      tester
          .widget<ScrollablePositionedList>(
            find.byType(ScrollablePositionedList),
          )
          .minCacheExtent,
      tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.75,
    );
    expect(
      tester
          .widget<ScrollablePositionedList>(
            find.byType(ScrollablePositionedList),
          )
          .addAutomaticKeepAlives,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('auto-page-turn-toggle')),
      findsNothing,
    );
  });

  testWidgets('continuous reader remembers page ratios after rebuilding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'readerOverlay': true,
      'swipeToggle': false,
      'lastPageSwipeEnabled': false,
    });
    final preferences = await SharedPreferences.getInstance();
    late StateSetter rebuild;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          getNextAndPreviousChaptersProvider(
            mangaId: 1,
            chapterId: 1,
          ).overrideWith((_) => null),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ContinuousReaderMode(
                manga: _manga,
                chapter: _chapter,
                chapterPages: _chapterPages,
                initialPage: 0,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final firstBuild = _serverImage(tester, '/page-1');
    expect(firstBuild.placeholderAspectRatio, isNull);
    firstBuild.onAspectRatioResolved!(0.1);

    rebuild(() {});
    await tester.pump();

    expect(_serverImage(tester, '/page-1').placeholderAspectRatio, 0.1);
  });

  testWidgets('paged reader automatically advances with a smooth transition', (
    tester,
  ) async {
    await _pumpAutoPageTurnReader(tester, transitionIndex: 0);

    await tester.tap(find.byKey(const ValueKey('auto-page-turn-toggle')));
    await tester.pump();

    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 250));

    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page, inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 300));

    expect(_readerIndex(tester), 1);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('paged reader can fade between automatically advanced pages', (
    tester,
  ) async {
    await _pumpAutoPageTurnReader(tester, transitionIndex: 1);

    await tester.tap(find.byKey(const ValueKey('auto-page-turn-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(_autoPageTurnFade(tester).opacity, 0);
    expect(_readerIndex(tester), 0);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(_autoPageTurnFade(tester).opacity, 1);
    expect(_readerIndex(tester), 1);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('paged reader can crossfade automatically advanced pages', (
    tester,
  ) async {
    await _pumpAutoPageTurnReader(tester, transitionIndex: 2);

    await tester.tap(find.byKey(const ValueKey('auto-page-turn-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final crossFade = find.byKey(
      const ValueKey('auto-page-turn-cross-fade'),
    );
    expect(crossFade, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(crossFade).opacity, 1);
    expect(_autoPageTurnFade(tester).opacity, 1);
    expect(_readerIndex(tester), 0);
    expect(
      tester
          .widget<ServerImage>(
            find.descendant(of: crossFade, matching: find.byType(ServerImage)),
          )
          .imageUrl,
      '/page-2',
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(crossFade, findsNothing);
    expect(_readerIndex(tester), 1);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });
}

Future<void> _pumpAutoPageTurnReader(
  WidgetTester tester, {
  required int transitionIndex,
}) async {
  SharedPreferences.setMockInitialValues({
    'readerOverlay': true,
    'swipeToggle': false,
    'lastPageSwipeEnabled': false,
    'autoPageTurnInterval': 0.5,
    'autoPageTurnTransition': transitionIndex,
  });
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        getNextAndPreviousChaptersProvider(
          mangaId: 1,
          chapterId: 1,
        ).overrideWith((_) => null),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SinglePageReaderMode(
          manga: _manga,
          chapter: _chapter,
          chapterPages: _chapterPages,
          initialPage: 0,
        ),
      ),
    ),
  );
  await tester.pump();
}

int _readerIndex(WidgetTester tester) =>
    tester.widget<ReaderWrapper>(find.byType(ReaderWrapper)).currentIndex;

ServerImage _serverImage(WidgetTester tester, String imageUrl) => tester
    .widgetList<ServerImage>(find.byType(ServerImage))
    .singleWhere((image) => image.imageUrl == imageUrl);

AnimatedOpacity _autoPageTurnFade(WidgetTester tester) => tester.widget(
      find.byKey(const ValueKey('auto-page-turn-fade')),
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
  pageCount: 2,
  sourceOrder: 1,
  uploadDate: '0',
  url: '',
  meta: const [],
);

final _chapterPages = Fragment$ChapterPagesDto(
  chapter: Fragment$ChapterPagesDto$chapter(id: 1, pageCount: 2),
  pages: const ['/page-1', '/page-2'],
);
