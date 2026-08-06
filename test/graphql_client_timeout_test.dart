import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/db_keys.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';

void main() {
  test('HTTP GraphQL clients use the configured server request timeout',
      () async {
    SharedPreferences.setMockInitialValues({
      DBKeys.serverRequestTimeout.name: 8000,
    });
    final preferences = await SharedPreferences.getInstance();
    final cacheDirectory =
        await Directory.systemTemp.createTemp('graphql_timeout_test');
    HiveStore.init(onPath: cacheDirectory.path);
    final store = await HiveStore.open(boxName: 'graphqlTimeoutTest');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        hiveStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await store.box.close();
      await cacheDirectory.delete(recursive: true);
    });

    const expectedTimeout = Duration(seconds: 8);

    expect(
      container.read(graphQlClientProvider).queryManager.requestTimeout,
      expectedTimeout,
    );
    expect(
      container.read(graphQlPublicClientProvider).queryManager.requestTimeout,
      expectedTimeout,
    );
  });
}
