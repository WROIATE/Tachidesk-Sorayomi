import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart';
import 'package:graphql/client.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';

void main() {
  test('details refresh manga metadata together with chapters', () async {
    Request? capturedRequest;
    final client = GraphQLClient(
      link: Link.function(
        (request, [__]) {
          capturedRequest = request;
          return Stream.value(
            const Response(
              data: {
                'fetchMangaAndChapters': {
                  'chapters': [],
                  '__typename': 'FetchMangaAndChaptersPayload',
                },
                '__typename': 'Mutation',
              },
              response: {},
            ),
          );
        },
      ),
      cache: GraphQLCache(),
    );
    final repository = MangaBookRepository(client);

    final chapters = await repository.getChapterList(42);

    expect(chapters, isEmpty);
    expect(capturedRequest?.variables['input'], {
      'fetchChapters': true,
      'fetchManga': true,
      'id': 42,
    });
    expect(
      printNode(capturedRequest!.operation.document),
      contains('fetchMangaAndChapters'),
    );
  });
}
