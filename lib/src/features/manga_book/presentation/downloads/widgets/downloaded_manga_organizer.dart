// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/sort_list_tile.dart';
import '../../../../library/presentation/category/controller/edit_category_controller.dart';
import '../controller/downloads_controller.dart';
import '../models/downloaded_manga_group.dart';

class DownloadedMangaOrganizer extends StatelessWidget {
  const DownloadedMangaOrganizer({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: TabBar(
          tabs: [
            Tab(text: context.l10n.filter),
            Tab(text: context.l10n.sort),
          ],
        ),
        body: const TabBarView(
          children: [
            _DownloadedCategoryFilter(),
            _DownloadedMangaSort(),
          ],
        ),
      ),
    );
  }
}

class _DownloadedCategoryFilter extends ConsumerWidget {
  const _DownloadedCategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(nonZeroCategoryListProvider);
    final selectedCategoryId = ref.watch(downloadedMangaCategoryFilterProvider);

    return categories.showUiWhenData(
      context,
      (data) => ListView(
        children: [
          ListTile(
            leading: Icon(
              selectedCategoryId == null
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
            ),
            title: Text(context.l10n.allCategories),
            selected: selectedCategoryId == null,
            onTap: () => ref
                .read(downloadedMangaCategoryFilterProvider.notifier)
                .update(null),
          ),
          for (final category in [...?data])
            ListTile(
              leading: Icon(
                selectedCategoryId == category.id
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
              ),
              title: Text(category.name),
              selected: selectedCategoryId == category.id,
              onTap: () => ref
                  .read(downloadedMangaCategoryFilterProvider.notifier)
                  .update(category.id),
            ),
        ],
      ),
      showGenericError: true,
      refresh: () => ref.invalidate(categoryControllerProvider),
    );
  }
}

class _DownloadedMangaSort extends ConsumerWidget {
  const _DownloadedMangaSort();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortSetting = ref.watch(downloadedMangaSortSettingsProvider);
    final controller = ref.read(downloadedMangaSortSettingsProvider.notifier);

    return ListView(
      children: [
        for (final sort in DownloadedMangaSort.values)
          SortListTile(
            selected: sortSetting.by == sort,
            title: Text(
              switch (sort) {
                DownloadedMangaSort.lastUpdated =>
                  context.l10n.mangaSortLastUpdated,
                DownloadedMangaSort.alphabetical =>
                  context.l10n.mangaSortAlphabetical,
              },
            ),
            ascending: sortSetting.ascending,
            onChanged: (_) => controller.toggleDirection(),
            onSelected: () => controller.select(sort),
          ),
      ],
    );
  }
}
