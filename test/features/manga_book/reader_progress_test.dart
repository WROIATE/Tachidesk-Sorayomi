import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_batch/chapter_batch_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/utils/reader_progress.dart';
import 'package:tachidesk_sorayomi/src/utils/extensions/custom_extensions.dart';

void main() {
  test('completed progress keeps the actual last page', () {
    const progress = ReaderProgressUpdate(
      pageIndex: 11,
      isCompleted: true,
    );

    expect(
      progress.toChapterChange().toJson(),
      {'isRead': true, 'lastPageRead': 11},
    );
  });

  test('partial progress marks a reread chapter as in progress', () {
    const progress = ReaderProgressUpdate(
      pageIndex: 5,
      isCompleted: false,
    );

    expect(
      progress.toChapterChange().toJson(),
      {'isRead': false, 'lastPageRead': 5},
    );
  });

  test('first page is a valid progress update', () {
    const progress = ReaderProgressUpdate(
      pageIndex: 0,
      isCompleted: false,
    );

    expect(
      progress.toChapterChange().toJson(),
      {'isRead': false, 'lastPageRead': 0},
    );
  });

  testWidgets('debounces rapid updates to the latest page', (tester) async {
    final saved = <ReaderProgressUpdate>[];
    final saver = ReaderProgressSaver(
      delay: const Duration(seconds: 1),
      save: (progress) async => saved.add(progress),
    );

    saver.schedule(
      const ReaderProgressUpdate(pageIndex: 5, isCompleted: false),
    );
    await tester.pump(const Duration(milliseconds: 500));
    saver.schedule(
      const ReaderProgressUpdate(pageIndex: 4, isCompleted: false),
    );
    await tester.pump(const Duration(milliseconds: 500));
    saver.schedule(
      const ReaderProgressUpdate(pageIndex: 2, isCompleted: false),
    );

    expect(saved, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await saver.flush();

    expect(saved.map((progress) => progress.pageIndex), [2]);
  });

  test('flush saves pending progress without waiting for the debounce',
      () async {
    final saved = <ReaderProgressUpdate>[];
    final saver = ReaderProgressSaver(
      save: (progress) async => saved.add(progress),
    );

    saver.schedule(
      const ReaderProgressUpdate(pageIndex: 5, isCompleted: false),
    );
    await saver.flush();

    expect(saved.map((progress) => progress.pageIndex), [5]);
  });

  test('completed progress replaces a pending partial update', () async {
    final saved = <ReaderProgressUpdate>[];
    final saver = ReaderProgressSaver(
      save: (progress) async => saved.add(progress),
    );

    saver.schedule(
      const ReaderProgressUpdate(pageIndex: 5, isCompleted: false),
    );
    await saver.saveImmediately(
      const ReaderProgressUpdate(pageIndex: 11, isCompleted: true),
    );

    expect(saved, hasLength(1));
    expect(saved.single.pageIndex, 11);
    expect(saved.single.isCompleted, isTrue);
  });

  test('chapter progress matches the current server reader mutation', () async {
    Request? capturedRequest;
    final client = GraphQLClient(
      link: Link.function(
        (request, [__]) {
          capturedRequest = request;
          return Stream.value(
            const Response(
              errors: [GraphQLError(message: 'update failed')],
              response: {},
            ),
          );
        },
      ),
      cache: GraphQLCache(),
    );
    final repository = MangaBookRepository(client);

    await expectLater(
      repository.putChapter(
        chapterId: 1,
        patch: ChapterChange(lastPageRead: 5),
      ),
      throwsA(isA<OperationMessageException>()),
    );

    expect(capturedRequest?.variables['input'], {
      'ids': [1],
      'patch': {'lastPageRead': 5},
    });
  });
}
