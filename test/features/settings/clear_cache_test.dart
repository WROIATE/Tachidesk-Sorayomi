import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart';
import 'package:graphql/client.dart';
import 'package:tachidesk_sorayomi/src/features/settings/data/settings_repository.dart';

void main() {
  test('clear cache requests server page and thumbnail cache cleanup',
      () async {
    Request? capturedRequest;
    final client = GraphQLClient(
      link: Link.function(
        (request, [__]) {
          capturedRequest = request;
          return Stream.value(
            const Response(
              data: {
                'clearCachedImages': {
                  'cachedPages': true,
                  'cachedThumbnails': true,
                  '__typename': 'ClearCachedImagesPayload',
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
    final repository = SettingsRepository(client);

    await repository.clearCachedImages();

    final operation = printNode(capturedRequest!.operation.document);
    expect(operation, contains('cachedPages: true'));
    expect(operation, contains('cachedThumbnails: true'));
    expect(operation, isNot(contains('downloadedThumbnails: true')));
  });
}
