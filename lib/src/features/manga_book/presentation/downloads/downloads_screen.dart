// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/app_sizes.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/search_field.dart';
import '../../data/downloads/downloads_repository.dart';
import '../../domain/downloads/downloads_model.dart';
import 'controller/downloads_controller.dart';
import 'widgets/download_progress_list_tile.dart';
import 'widgets/downloaded_manga_list.dart';
import 'widgets/downloaded_manga_organizer.dart';
import 'widgets/downloads_fab.dart';

class DownloadsScreen extends HookConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: 2);
    useListenable(tabController);
    final showSearch = useState(false);
    final toast = ref.watch(toastProvider);
    final downloadsChapterIds = ref.watch(downloadsChapterIdsProvider);
    final downloadsGlobalStatus = ref.watch(downloaderStateProvider);
    final showDownloadsFAB = ref.watch(showDownloadsFABProvider);
    final downloadedMangaQuery = ref.watch(downloadedMangaQueryProvider);
    final downloadedMangaCategory =
        ref.watch(downloadedMangaCategoryFilterProvider);
    final downloadedMangaSort = ref.watch(downloadedMangaSortSettingsProvider);
    if (TickerMode.valuesOf(context).enabled) {
      ref.watch(downloadStatusWatchdogProvider);
    }
    ref.listen(downloadsChapterIdsProvider, (previous, next) {
      final nextIds = next.toSet();
      if (previous != null &&
          previous.any((chapterId) => !nextIds.contains(chapterId))) {
        ref.invalidate(downloadedChaptersProvider);
      }
    });

    final isQueueTab = tabController.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: !isQueueTab && showSearch.value
            ? SearchField(
                initialText: downloadedMangaQuery,
                onChanged:
                    ref.read(downloadedMangaQueryProvider.notifier).update,
                onClose: () => showSearch.value = false,
              )
            : Text(context.l10n.downloads),
        actions: [
          if (isQueueTab && downloadsChapterIds.isNotBlank)
            IconButton(
              onPressed: () async {
                final result = await AsyncValue.guard(
                  ref.read(downloadsRepositoryProvider).clearDownloads,
                );
                result.showToastOnError(toast);
                if (!result.hasError) {
                  ref.invalidate(downloadStatusProvider);
                }
              },
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          if (!isQueueTab && !showSearch.value) ...[
            IconButton(
              tooltip: context.l10n.search,
              onPressed: () => showSearch.value = true,
              icon: const Icon(Icons.search_rounded),
            ),
            Builder(
              builder: (context) => IconButton(
                tooltip: context.l10n.filter,
                onPressed: () {
                  if (context.isTablet) {
                    Scaffold.of(context).openEndDrawer();
                  } else {
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: KBorderRadius.rT16.radius,
                      ),
                      clipBehavior: Clip.hardEdge,
                      builder: (_) => const DownloadedMangaOrganizer(),
                    );
                  }
                },
                icon: Badge(
                  isLabelVisible: downloadedMangaCategory != null,
                  child: const Icon(Icons.filter_list_rounded),
                ),
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: tabController,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: context.l10n.downloading),
            Tab(text: context.l10n.downloaded),
          ],
        ),
      ),
      floatingActionButton: isQueueTab && showDownloadsFAB
          ? DownloadsFab(
              status:
                  downloadsGlobalStatus.valueOrNull ?? DownloaderState.STARTED)
          : null,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: context.isTablet && !isQueueTab
          ? const Drawer(
              width: kDrawerWidth,
              shape: RoundedRectangleBorder(),
              child: DownloadedMangaOrganizer(),
            )
          : null,
      body: TabBarView(
        controller: tabController,
        children: [
          const _DownloadQueueTab(),
          DownloadedMangaList(
            query: downloadedMangaQuery,
            categoryId: downloadedMangaCategory,
            sortSetting: downloadedMangaSort,
          ),
        ],
      ),
    );
  }
}

class _DownloadQueueTab extends ConsumerWidget {
  const _DownloadQueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refreshDownloads() async {
      ref.invalidate(downloadUpdatesProvider);
      final _ = await ref.refresh(downloadStatusProvider.future);
    }

    final toast = ref.watch(toastProvider);
    final downloadsChapterIds = ref.watch(downloadsChapterIdsProvider);
    final downloadsGlobalStatus = ref.watch(downloaderStateProvider);

    return downloadsGlobalStatus.showUiWhenData(
      context,
      (data) {
        if (data == null) {
          return Emoticons(title: context.l10n.errorSomethingWentWrong);
        } else if (downloadsChapterIds.isBlank) {
          return Emoticons(title: context.l10n.noDownloads);
        } else {
          final downloadsCount =
              (downloadsChapterIds.length).getValueOnNullOrNegative();
          return RefreshIndicator(
            onRefresh: refreshDownloads,
            child: ListView.builder(
              itemExtent: 104,
              itemBuilder: (context, index) {
                if (index == downloadsCount) return const Gap(104);
                final chapterId = downloadsChapterIds[index];
                return DownloadProgressListTile(
                  key: ValueKey("$chapterId"),
                  index: index,
                  downloadsCount: downloadsCount,
                  chapterId: chapterId,
                  toast: toast,
                );
              },
              itemCount: downloadsCount + 1,
            ),
          );
        }
      },
      showGenericError: true,
      refresh: () {
        ref.invalidate(downloadUpdatesProvider);
        ref.invalidate(downloadStatusProvider);
      },
    );
  }
}
