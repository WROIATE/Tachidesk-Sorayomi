import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const _legacyGraphQlCacheFiles = [
  'graphqlclientstore.hive',
  'graphqlclientstore.hivec',
  'graphqlclientstore.lock',
];

Future<void> deleteLegacyGraphQlCache() async {
  try {
    await deleteLegacyGraphQlCacheFiles(
      await getApplicationDocumentsDirectory(),
    );
  } catch (_) {
    // Cache cleanup must never prevent the app from starting.
  }
}

@visibleForTesting
Future<void> deleteLegacyGraphQlCacheFiles(Directory directory) async {
  for (final fileName in _legacyGraphQlCacheFiles) {
    final file = File(path.join(directory.path, fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
