import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql/client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/chapter_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/chapter_page_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/manga_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/reader_screen.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/routes/router_config.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('reader back navigation on $platform', (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      Page<void>? readerPage;
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Manga details')),
          ),
          GoRoute(
            path: '/reader',
            pageBuilder: (context, state) {
              readerPage = ReaderRoute(
                mangaId: 1,
                chapterId:
                    int.parse(state.uri.queryParameters['chapter'] ?? '2'),
                startAtBeginning:
                    state.uri.queryParameters.containsKey('chapter'),
              ).buildPage(context, state);
              return readerPage!;
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          mangaBookRepositoryProvider.overrideWithValue(_EmptyRepository()),
        ],
        child: MaterialApp.router(
          theme: ThemeData(platform: platform),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      router.push('/reader');
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);

      if (platform == TargetPlatform.iOS) {
        // A slow, short edge drag must be cancellable.
        final gesture = await tester.startGesture(const Offset(1, 500));
        await gesture.moveBy(const Offset(100, 0));
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(ReaderScreen), findsOneWidget);

        // Switching chapters replaces the reader but must retain back support.
        router.replace('/reader?chapter=3');
        await tester.pumpAndSettle();
        expect(tester.widget<ReaderScreen>(find.byType(ReaderScreen)).chapterId,
            3);
        await tester.dragFrom(
          const Offset(1, 500),
          const Offset(800, 0),
        );
      } else {
        expect(readerPage, isA<CustomTransitionPage<void>>());
        router.pop();
      }
      await tester.pumpAndSettle();
      expect(find.text('Manga details'), findsOneWidget);
      expect(find.byType(ReaderScreen), findsNothing);
    });
  }
}

class _EmptyRepository extends MangaBookRepository {
  _EmptyRepository()
      : super(GraphQLClient(
            link: Link.function((_, [__]) => const Stream<Response>.empty()),
            cache: GraphQLCache()));

  @override
  Future<MangaDto?> getManga({required int mangaId}) async => null;

  @override
  Future<ChapterDto?> getChapter({required int chapterId}) async => null;

  @override
  Future<ChapterPagesDto?> getChapterPages({required int chapterId}) async =>
      null;
}
