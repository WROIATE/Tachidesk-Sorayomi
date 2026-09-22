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
    for (final vertical in [false, true]) {
      for (final previous in [false, true]) {
        testWidgets(
            'chapter direction and back on $platform (vertical: $vertical, previous: $previous)',
            (tester) async {
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
                    transVertical:
                        state.uri.queryParameters.containsKey('chapter')
                            ? vertical
                            : null,
                    toPrev: state.uri.queryParameters.containsKey('chapter')
                        ? previous
                        : null,
                    startAtBeginning:
                        state.uri.queryParameters.containsKey('chapter') &&
                            !previous,
                    startAtEnd:
                        state.uri.queryParameters.containsKey('chapter') &&
                            previous,
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

          // Use the same animated replacement as real chapter navigation.
          router.pushReplacement('/reader?chapter=3');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final chapter = find.byWidgetPredicate(
            (widget) => widget is ReaderScreen && widget.chapterId == 3,
          );
          final entryElement = tester.element(chapter);
          final position = tester.getTopLeft(chapter);
          final oldChapter = find.byWidgetPredicate(
            (widget) => widget is ReaderScreen && widget.chapterId == 2,
          );
          expect(tester.getTopLeft(oldChapter), Offset.zero,
              reason: 'Chapter replacement must not add leftward parallax');
          final displacement = vertical ? position.dy : position.dx;
          expect(displacement, previous ? lessThan(0) : greaterThan(0));
          expect(vertical ? position.dx : position.dy, closeTo(0, 0.01));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(chapter), Offset.zero);
          expect(identical(tester.element(chapter), entryElement), isTrue,
              reason: 'Completing entry must preserve reader state');

          if (platform == TargetPlatform.iOS) {
            // A slow, short edge drag must be cancellable.
            final gesture = await tester.startGesture(const Offset(1, 500));
            await gesture.moveBy(const Offset(100, 0));
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.getTopLeft(chapter).dx, greaterThan(0));
            expect(tester.getTopLeft(chapter).dy, closeTo(0, 0.01));
            await gesture.up();
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.getTopLeft(chapter).dx, greaterThanOrEqualTo(0));
            expect(tester.getTopLeft(chapter).dy, closeTo(0, 0.01));
            await tester.pumpAndSettle();
            expect(tester.getTopLeft(chapter), Offset.zero);
            expect(identical(tester.element(chapter), entryElement), isTrue);
            expect(find.byType(ReaderScreen), findsOneWidget);

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
