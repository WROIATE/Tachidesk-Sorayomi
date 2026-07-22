import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:tachidesk_sorayomi/src/features/history/data/history_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tachidesk_sorayomi/src/utils/extensions/custom_extensions.dart';

void main() {
  test('history includes first-page and non-library reading records', () async {
    Request? capturedRequest;
    final client = GraphQLClient(
      link: Link.function(
        (request, [__]) {
          capturedRequest = request;
          return Stream.value(
            const Response(
              errors: [GraphQLError(message: 'query stopped after capture')],
              response: {},
            ),
          );
        },
      ),
      cache: GraphQLCache(),
    );
    final repository = HistoryRepository(
      client,
      MangaBookRepository(client),
    );

    await expectLater(
      repository.getReadingHistory(),
      throwsA(isA<OperationMessageException>()),
    );

    expect(capturedRequest?.variables['filter'], {
      'lastReadAt': {
        'isNull': false,
        'notEqualToAll': ['0'],
      },
    });
  });
}
