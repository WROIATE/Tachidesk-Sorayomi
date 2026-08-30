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
    final store = InMemoryStore();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        graphQlStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

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

  test('GraphQL clients never persist operation results', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        graphQlStoreProvider.overrideWithValue(InMemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    final clients = [
      container.read(graphQlPublicClientProvider),
      container.read(graphQlClientProvider),
      container.read(graphQlSubscriptionClientProvider),
    ];

    for (final client in clients) {
      final policies = client.defaultPolicies;
      expect(policies.watchQuery.fetch, FetchPolicy.noCache);
      expect(policies.watchMutation.fetch, FetchPolicy.noCache);
      expect(policies.query.fetch, FetchPolicy.noCache);
      expect(policies.mutate.fetch, FetchPolicy.noCache);
      expect(policies.subscribe.fetch, FetchPolicy.noCache);
    }
  });
}
