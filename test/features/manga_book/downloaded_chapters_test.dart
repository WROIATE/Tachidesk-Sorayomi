import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gql/language.dart';
import 'package:graphql/client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/downloads/downloads_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/chapter_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/downloads/controller/downloads_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/downloads/downloaded_manga_screen.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/downloads/models/downloaded_manga_group.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/routes/router_config.dart';

void main() {
  test(
    'downloaded chapters use server filtering, paginate, and group by manga',
    () async {
      final requests = <Request>[];
      final client = GraphQLClient(
        link: Link.function(
          (request, [__]) {
            requests.add(request);
            final after = request.variables['after'];
            final isFirstPage = after == null;
            return Stream.value(
              Response(
                data: {
                  'chapters': {
                    'nodes': isFirstPage
                        ? [
                            _chapter(
                              id: 1,
                              mangaId: 2,
                              mangaTitle: 'Beta',
                              sourceOrder: 5,
                            ),
                            _chapter(
                              id: 2,
                              mangaId: 1,
                              mangaTitle: 'Alpha',
                              sourceOrder: 1,
                            ),
                          ]
                        : [
                            _chapter(
                              id: 3,
                              mangaId: 1,
                              mangaTitle: 'Alpha',
                              sourceOrder: 3,
                            ),
                          ],
                    'pageInfo': {
                      'endCursor': isFirstPage ? '2' : '3',
                      'hasNextPage': isFirstPage,
                      'hasPreviousPage': !isFirstPage,
                      'startCursor': isFirstPage ? '1' : '3',
                      '__typename': 'PageInfo',
                    },
                    'totalCount': 3,
                    '__typename': 'ChapterNodeList',
                  },
                  '__typename': 'Query',
                },
                response: const {},
              ),
            );
          },
        ),
        cache: GraphQLCache(),
      );
      final repository = DownloadsRepository(client, client);

      final chapters = await repository.getDownloadedChapters(mangaId: 1);

      expect(requests, hasLength(2));
      expect(requests.first.variables, {
        'condition': {'isDownloaded': true, 'mangaId': 1},
        'first': 100,
      });
      expect(requests.last.variables, {
        'after': 2,
        'condition': {'isDownloaded': true, 'mangaId': 1},
        'first': 100,
      });
      expect(
        printNode(requests.first.operation.document),
        contains(r'condition: $condition'),
      );
      expect(chapters.map((chapter) => chapter.id), [1, 2, 3]);
    },
  );

  test('downloaded manga groups support keyword, category, and sorting', () {
    final chapters = [
      _chapterDto(
        id: 1,
        mangaId: 2,
        mangaTitle: 'Beta',
        sourceOrder: 5,
      ),
      _chapterDto(
        id: 2,
        mangaId: 1,
        mangaTitle: 'Alpha',
        sourceOrder: 1,
      ),
      _chapterDto(
        id: 3,
        mangaId: 1,
        mangaTitle: 'Alpha',
        sourceOrder: 3,
      ),
    ];
    final groups = groupDownloadedChapters(chapters);

    final byTime = filterAndSortDownloadedMangaGroups(
      groups,
      query: null,
      categoryMangaIds: null,
      sortSetting: (
        by: DownloadedMangaSort.lastUpdated,
        ascending: false,
      ),
    );
    final byName = filterAndSortDownloadedMangaGroups(
      groups,
      query: null,
      categoryMangaIds: null,
      sortSetting: (
        by: DownloadedMangaSort.alphabetical,
        ascending: true,
      ),
    );
    final filtered = filterAndSortDownloadedMangaGroups(
      groups,
      query: 'beta',
      categoryMangaIds: {2},
      sortSetting: (
        by: DownloadedMangaSort.alphabetical,
        ascending: true,
      ),
    );

    expect(byTime.map((group) => group.manga.title), ['Beta', 'Alpha']);
    expect(byName.map((group) => group.manga.title), ['Alpha', 'Beta']);
    expect(filtered.single.manga.id, 2);
    expect(
      byName.first.chapters.map((chapter) => chapter.id),
      [3, 2],
    );
  });

  test('download routes open dedicated pages outside main navigation', () {
    const route = DownloadedMangaRoute(mangaId: 42);

    expect(route.location, '/downloads/manga/42');

    final quickSearchShell = $appRoutes.single as ShellRoute;
    final downloadRoutes = quickSearchShell.routes
        .whereType<GoRoute>()
        .where(
          (route) =>
              route.path == Routes.downloads ||
              route.path == Routes.downloadedManga,
        )
        .toList();

    expect(downloadRoutes.map((route) => route.path), {
      Routes.downloads,
      Routes.downloadedManga,
    });
    expect(downloadRoutes.every((route) => route.routes.isEmpty), isTrue);
  });

  testWidgets('long press enters downloaded chapter multi-select mode', (
    tester,
  ) async {
    final chapters = [
      _chapterDto(
        id: 1,
        mangaId: 1,
        mangaTitle: 'Alpha',
        sourceOrder: 1,
      ),
      _chapterDto(
        id: 2,
        mangaId: 1,
        mangaTitle: 'Alpha',
        sourceOrder: 2,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedMangaChaptersProvider(1).overrideWith(
            (ref) async => chapters,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DownloadedMangaScreen(mangaId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mangaHeader = find.byKey(
      const ValueKey('downloaded-manga-header-1'),
    );
    expect(mangaHeader, findsOneWidget);
    expect(tester.widget<InkWell>(mangaHeader).onTap, isNotNull);

    await tester.longPress(find.byKey(const ValueKey('downloaded-chapter-1')));
    await tester.pump();

    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.byIcon(Icons.delete_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('downloaded-chapter-2')));
    await tester.pump();
    expect(find.text('2 Selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.flip_to_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_rounded), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
  });
}

ChapterWithMangaDto _chapterDto({
  required int id,
  required int mangaId,
  required String mangaTitle,
  required int sourceOrder,
}) =>
    ChapterWithMangaDto.fromJson(
      _chapter(
        id: id,
        mangaId: mangaId,
        mangaTitle: mangaTitle,
        sourceOrder: sourceOrder,
      ),
    );

Map<String, Object?> _chapter({
  required int id,
  required int mangaId,
  required String mangaTitle,
  required int sourceOrder,
}) =>
    {
      'chapterNumber': sourceOrder.toDouble(),
      'fetchedAt': '$sourceOrder',
      'id': id,
      'isBookmarked': false,
      'isDownloaded': true,
      'isRead': false,
      'lastPageRead': 0,
      'lastReadAt': '0',
      'mangaId': mangaId,
      'name': 'Chapter $sourceOrder',
      'pageCount': 10,
      'realUrl': null,
      'scanlator': null,
      'sourceOrder': sourceOrder,
      'uploadDate': '0',
      'url': '/chapter/$id',
      'meta': const [],
      'manga': {
        'age': null,
        'artist': null,
        'author': null,
        'chaptersLastFetchedAt': null,
        'description': null,
        'genre': const [],
        'id': mangaId,
        'inLibrary': true,
        'inLibraryAt': '0',
        'initialized': true,
        'lastFetchedAt': null,
        'meta': const [],
        'realUrl': null,
        'sourceId': '1',
        'status': 'ONGOING',
        'thumbnailUrl': null,
        'thumbnailUrlLastFetched': null,
        'title': mangaTitle,
        'unreadCount': 0,
        'updateStrategy': 'ALWAYS_UPDATE',
        'url': '/manga/$mangaId',
        '__typename': 'MangaType',
      },
      '__typename': 'ChapterType',
    };
