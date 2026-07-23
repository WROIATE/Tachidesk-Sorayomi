// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../routes/router_config.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/emoticons.dart';
import '../../../../../widgets/server_image.dart';
import '../controller/downloads_controller.dart';
import '../models/downloaded_manga_group.dart';

class DownloadedMangaList extends ConsumerWidget {
  const DownloadedMangaList({
    super.key,
    required this.query,
    required this.categoryId,
    required this.sortSetting,
  });

  final String? query;
  final int? categoryId;
  final DownloadedMangaSortSetting sortSetting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!TickerMode.valuesOf(context).enabled) {
      return const SizedBox.shrink();
    }
    final downloadedChapters = ref.watch(downloadedChaptersProvider);
    final categoryMangaIds = categoryId == null
        ? const AsyncData<Set<int>?>(null)
        : ref
            .watch(downloadedCategoryMangaIdsProvider(categoryId!))
            .whenData<Set<int>?>((ids) => ids);

    Future<void> refresh() async {
      ref.invalidate(downloadedChaptersProvider);
      final refreshes = <Future<Object?>>[
        ref.read(downloadedChaptersProvider.future),
      ];
      if (categoryId != null) {
        final provider = downloadedCategoryMangaIdsProvider(categoryId!);
        ref.invalidate(provider);
        refreshes.add(ref.read(provider.future));
      }
      await Future.wait(refreshes);
    }

    return downloadedChapters.showUiWhenData(
      context,
      (chapters) => categoryMangaIds.showUiWhenData(
        context,
        (mangaIds) {
          final groups = filterAndSortDownloadedMangaGroups(
            groupDownloadedChapters(chapters),
            query: query,
            categoryMangaIds: mangaIds,
            sortSetting: sortSetting,
          );
          return RefreshIndicator(
            onRefresh: refresh,
            child: groups.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: constraints.maxHeight,
                          child: Emoticons(
                            title: query.isNotBlank || categoryId != null
                                ? context.l10n.noCategoryMangaFound
                                : context.l10n.noChaptersFound,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: KEdgeInsets.v8.size,
                    itemCount: groups.length,
                    itemBuilder: (context, index) => _DownloadedMangaCard(
                      group: groups[index],
                    ),
                  ),
          );
        },
        showGenericError: true,
        refresh: categoryId == null
            ? null
            : () => ref.invalidate(
                  downloadedCategoryMangaIdsProvider(categoryId!),
                ),
      ),
      showGenericError: true,
      refresh: () => ref.invalidate(downloadedChaptersProvider),
    );
  }
}

class _DownloadedMangaCard extends StatelessWidget {
  const _DownloadedMangaCard({required this.group});

  final DownloadedMangaGroup group;

  @override
  Widget build(BuildContext context) {
    final manga = group.manga;
    return Card(
      margin: KEdgeInsets.h16v4.size,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('downloaded-manga-${manga.id}'),
        leading: manga.thumbnailUrl.isNotBlank
            ? ClipRRect(
                borderRadius: KBorderRadius.r8.radius,
                child: ServerImage(
                  imageUrl: manga.thumbnailUrl!,
                  size: const Size.square(56),
                ),
              )
            : const SizedBox.square(
                dimension: 56,
                child: Icon(Icons.menu_book_rounded),
              ),
        title: Text(
          manga.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(context.l10n.nChapters(group.chapters.length)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => DownloadedMangaRoute(mangaId: manga.id).push(context),
      ),
    );
  }
}
