import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/db_keys.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/domain/source/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/domain/source/source_model.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/presentation/global_search/controller/source_quick_search_controller.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/presentation/source/controller/source_controller.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';

void main() {
  test('source sections promote last used before pinned without duplicates',
      () {
    final alpha = source(id: '1', name: 'Alpha');
    final beta = source(id: '2', name: 'Beta');
    final gamma = source(id: '3', name: 'Gamma');
    final local = source(id: '4', name: 'Local', lang: 'localsourcelang');

    final sections = buildSourceSectionsForDisplay(
      {
        'lastUsed': [beta],
        'en': [alpha, beta, gamma],
        'localsourcelang': [local],
      },
      {'1', '2'},
    );

    expect(
      sections.keys,
      ['lastUsed', pinnedSourceGroupKey, 'en', 'localsourcelang'],
    );
    expect(sections['lastUsed']?.map((source) => source.id), ['2']);
    expect(
      sections[pinnedSourceGroupKey]?.map((source) => source.id),
      ['1'],
    );
    expect(sections['en']?.map((source) => source.id), ['3']);
    expect(sections['localsourcelang']?.map((source) => source.id), ['4']);
  });

  test('global search can use only pinned sources or all sources', () {
    final alpha = source(id: '1', name: 'Alpha');
    final beta = source(id: '2', name: 'Beta');
    final gamma = source(id: '3', name: 'Gamma');
    final sources = [gamma, alpha, beta, alpha];

    final pinned = filterAndSortGlobalSearchSources(
      sources,
      {'2'},
      GlobalSearchSourceFilter.pinned,
    );
    final all = filterAndSortGlobalSearchSources(
      sources,
      {'2'},
      GlobalSearchSourceFilter.all,
    );

    expect(pinned.map((source) => source.id), ['2']);
    expect(all.map((source) => source.id), ['2', '1', '3']);
  });

  test('pinned source ids are persisted when toggled', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    final subscription = container.listen<List<String>?>(
      pinnedSourceIdsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    container.read(pinnedSourceIdsProvider.notifier).toggle('1');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(pinnedSourceIdsProvider), ['1']);
    expect(
      preferences.getStringList(DBKeys.pinnedSourceIds.name),
      ['1'],
    );

    container.read(pinnedSourceIdsProvider.notifier).toggle('1');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(pinnedSourceIdsProvider), isEmpty);
    expect(
      preferences.getStringList(DBKeys.pinnedSourceIds.name),
      isEmpty,
    );
  });
}

SourceDto source({
  required String id,
  required String name,
  String lang = 'en',
}) {
  return Fragment$SourceDto(
    displayName: name,
    iconUrl: '',
    id: id,
    isConfigurable: false,
    isNsfw: false,
    lang: lang,
    name: name,
    supportsLatest: false,
    $extension: Fragment$SourceDto$extension(pkgName: 'test.extension'),
  );
}
