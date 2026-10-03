import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/graphql/__generated__/schema.graphql.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';

void main() {
  for (final mangaMode in [
    null,
    ReaderMode.defaultReader,
    ReaderMode.singleHorizontalLTR,
  ]) {
    for (final showHints in [true, false]) {
      testWidgets('LTR reader paints entry hints: $mangaMode, show: $showHints',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          DBKeys.readerMode.name: ReaderMode.singleHorizontalLTR.index,
          DBKeys.readerNavigationLayout.name:
              ReaderNavigationLayout.lShaped.index,
        });
        final preferences = await SharedPreferences.getInstance();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            mangaBookRepositoryProvider
                .overrideWithValue(_Repository(mangaMode)),
            getNextAndPreviousChaptersProvider(mangaId: 1, chapterId: 1)
                .overrideWith((_) => null),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReaderScreen(
              mangaId: 1,
              chapterId: 1,
              showReaderLayoutAnimation: showHints,
            ),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final layout = find.byType(LShapedLayout);
        expect(layout, findsOneWidget,
            reason:
                'The default manga layout must inherit the global L layout');
        final fills =
            find.descendant(of: layout, matching: find.byType(ColoredBox));
        final visibleColors = tester
            .widgetList<ColoredBox>(fills)
            .map((box) => box.color)
            .where((color) => color.a > 0);
        expect(visibleColors, showHints ? isNotEmpty : isEmpty,
            reason: 'Test the painted hint, not just the route parameter');

        await tester.pump(const Duration(seconds: 2));
        expect(tester.widgetList<ColoredBox>(fills), isEmpty,
            reason: 'Entry hints must fade out');
      });
    }
  }
}

class _Repository extends MangaBookRepository {
  _Repository(this.mangaMode)
      : super(GraphQLClient(
            link: Link.function((_, [__]) => const Stream<Response>.empty()),
            cache: GraphQLCache()));

  final ReaderMode? mangaMode;

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
            value: ReaderNavigationLayout.defaultNavigation.name,
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

  @override
  Future<Fragment$ChapterPagesDto?> getChapterPages(
          {required int chapterId}) async =>
      Fragment$ChapterPagesDto(
        chapter: Fragment$ChapterPagesDto$chapter(id: 1, pageCount: 1),
        pages: const ['/page-1'],
      );
}
