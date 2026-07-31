// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../global_providers/global_providers.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../data/source_repository/source_repository.dart';
import '../../../domain/source/source_model.dart';
import '../../source/controller/source_controller.dart';

part 'source_quick_search_controller.g.dart';

typedef QuickSearchResults = ({
  SourceDto source,
  AsyncValue<List<MangaDto>> mangaList
});

enum GlobalSearchSourceFilter { pinned, all }

@riverpod
Future<List<MangaDto>> sourceQuickSearchMangaList(
  Ref ref,
  String sourceId, {
  String? query,
}) async {
  final rateLimiterQueue = ref.watch(rateLimitQueueProvider(query));
  final mangaPage = await rateLimiterQueue
      .add(() => ref.watch(sourceRepositoryProvider).fetchSourceManga(
            page: 1,
            sourceId: sourceId,
            sourceType: SourceType.SEARCH,
            query: query,
          ));
  return [...?(mangaPage?.mangas)];
}

@riverpod
AsyncValue<List<QuickSearchResults>> quickSearchResults(
  Ref ref, {
  String? query,
  required GlobalSearchSourceFilter sourceFilter,
}) {
  final sourceMapData = ref.watch(sourceMapFilteredProvider);
  final pinnedSourceIds = {
    ...?ref.watch(pinnedSourceIdsProvider),
  };

  final sourceMap = {...?sourceMapData.valueOrNull}..remove("lastUsed");
  final sourceList = filterAndSortGlobalSearchSources(
    sourceMap.values.expand((sources) => sources),
    pinnedSourceIds,
    sourceFilter,
  );
  final List<QuickSearchResults> sourceMangaListPairList = [];
  for (SourceDto source in sourceList) {
    if (source.id.isNotBlank) {
      final mangaList = ref.watch(
        sourceQuickSearchMangaListProvider(source.id, query: query),
      );
      sourceMangaListPairList.add((mangaList: mangaList, source: source));
    }
  }

  return sourceMapData.copyWithData((_) => sourceMangaListPairList);
}

List<SourceDto> filterAndSortGlobalSearchSources(
  Iterable<SourceDto> sources,
  Set<String> pinnedSourceIds,
  GlobalSearchSourceFilter sourceFilter,
) {
  final uniqueSources = <String, SourceDto>{
    for (final source in sources) source.id: source,
  }.values;
  final filteredSources = uniqueSources
      .where(
        (source) =>
            sourceFilter == GlobalSearchSourceFilter.all ||
            pinnedSourceIds.contains(source.id),
      )
      .toList()
    ..sort((first, second) {
      final firstIsPinned = pinnedSourceIds.contains(first.id);
      final secondIsPinned = pinnedSourceIds.contains(second.id);
      if (firstIsPinned != secondIsPinned) {
        return firstIsPinned ? -1 : 1;
      }
      final nameComparison =
          first.name.toLowerCase().compareTo(second.name.toLowerCase());
      if (nameComparison != 0) return nameComparison;
      return first.id.compareTo(second.id);
    });

  return filteredSources;
}
