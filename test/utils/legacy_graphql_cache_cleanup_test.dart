import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/utils/cache/legacy_graphql_cache_cleanup_io.dart';

void main() {
  test('legacy GraphQL cleanup only removes its Hive box files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'legacy_graphql_cache_cleanup_test-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final legacyFiles = [
      File('${directory.path}/graphqlclientstore.hive'),
      File('${directory.path}/graphqlclientstore.hivec'),
      File('${directory.path}/graphqlclientstore.lock'),
    ];
    for (final file in legacyFiles) {
      await file.writeAsString('legacy cache');
    }
    final unrelatedFile = File('${directory.path}/keep.txt');
    await unrelatedFile.writeAsString('keep');

    await deleteLegacyGraphQlCacheFiles(directory);

    for (final file in legacyFiles) {
      expect(await file.exists(), isFalse);
    }
    expect(await unrelatedFile.exists(), isTrue);
  });
}
