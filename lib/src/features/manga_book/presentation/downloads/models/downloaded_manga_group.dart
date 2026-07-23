// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/manga/manga_model.dart';

enum DownloadedMangaSort {
  lastUpdated,
  alphabetical,
}

typedef DownloadedMangaSortSetting = ({
  DownloadedMangaSort by,
  bool ascending,
});

@immutable
class DownloadedMangaGroup {
  const DownloadedMangaGroup({
    required this.manga,
    required this.chapters,
    required this.latestFetchedAt,
  });

  final MangaBaseDto manga;
  final List<ChapterWithMangaDto> chapters;
  final int latestFetchedAt;
}

List<DownloadedMangaGroup> groupDownloadedChapters(
  Iterable<ChapterWithMangaDto> chapters,
) {
  final groupedChapters = <int, List<ChapterWithMangaDto>>{};
  for (final chapter in chapters) {
    groupedChapters.putIfAbsent(chapter.manga.id, () => []).add(chapter);
  }

  return groupedChapters.values.map((mangaChapters) {
    mangaChapters.sort((a, b) {
      final sourceOrder = b.sourceOrder.compareTo(a.sourceOrder);
      return sourceOrder != 0 ? sourceOrder : b.id.compareTo(a.id);
    });
    return DownloadedMangaGroup(
      manga: mangaChapters.first.manga,
      chapters: List.unmodifiable(mangaChapters),
      latestFetchedAt: mangaChapters.fold(
        0,
        (latest, chapter) {
          final fetchedAt = int.tryParse(chapter.fetchedAt) ?? 0;
          return fetchedAt > latest ? fetchedAt : latest;
        },
      ),
    );
  }).toList();
}

List<DownloadedMangaGroup> filterAndSortDownloadedMangaGroups(
  Iterable<DownloadedMangaGroup> groups, {
  required String? query,
  required Set<int>? categoryMangaIds,
  required DownloadedMangaSortSetting sortSetting,
}) {
  final filteredGroups = groups.where((group) {
    if (categoryMangaIds != null &&
        !categoryMangaIds.contains(group.manga.id)) {
      return false;
    }
    if (query.isBlank) {
      return true;
    }
    final manga = group.manga;
    return manga.title.query(query) ||
        manga.author.query(query) ||
        manga.artist.query(query) ||
        manga.genre.join(',').query(query);
  }).toList();

  filteredGroups.sort((a, b) {
    final comparison = switch (sortSetting.by) {
      DownloadedMangaSort.alphabetical =>
        a.manga.title.toLowerCase().compareTo(b.manga.title.toLowerCase()),
      DownloadedMangaSort.lastUpdated =>
        a.latestFetchedAt.compareTo(b.latestFetchedAt),
    };
    final withTieBreaker = comparison != 0
        ? comparison
        : a.manga.title.toLowerCase().compareTo(b.manga.title.toLowerCase());
    return sortSetting.ascending ? withTieBreaker : -withTieBreaker;
  });
  return filteredGroups;
}
