import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/features/library/presentation/library/controller/library_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/manga_model.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/graphql/__generated__/schema.graphql.dart';

void main() {
  test('library hides category members that are no longer in the library',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        categoryMangaListProvider(1).overrideWith(
          (ref) async => [
            _manga(id: 1, title: 'Kept', inLibrary: true),
            _manga(id: 2, title: 'Removed', inLibrary: false),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(categoryMangaListProvider(1).future);
    final mangas = container
        .read(
          categoryMangaListWithQueryAndFilterProvider(categoryId: 1),
        )
        .valueOrNull;

    expect(mangas?.map((manga) => manga.title), ['Kept']);
  });
}

MangaDto _manga({
  required int id,
  required String title,
  required bool inLibrary,
}) =>
    MangaDto(
      downloadCount: 0,
      genre: const [],
      id: id,
      inLibrary: inLibrary,
      inLibraryAt: '0',
      initialized: true,
      meta: const [],
      sourceId: '1',
      status: Enum$MangaStatus.ONGOING,
      title: title,
      unreadCount: 0,
      updateStrategy: Enum$UpdateStrategy.ALWAYS_UPDATE,
      url: '/manga/$id',
    );
