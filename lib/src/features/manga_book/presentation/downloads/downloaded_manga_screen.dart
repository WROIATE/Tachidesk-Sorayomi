// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/app_sizes.dart';
import '../../../../routes/router_config.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/server_image.dart';
import '../../domain/chapter/chapter_model.dart';
import '../../domain/manga/manga_model.dart';
import 'controller/downloads_controller.dart';
import 'widgets/downloaded_chapters_delete_bar.dart';

@visibleForTesting
List<ChapterWithMangaDto> sortDownloadedMangaChapters(
  Iterable<ChapterWithMangaDto> chapters,
) =>
    chapters.toList()
      ..sort((a, b) {
        final sourceOrder = b.sourceOrder.compareTo(a.sourceOrder);
        return sourceOrder != 0 ? sourceOrder : b.id.compareTo(a.id);
      });

class DownloadedMangaScreen extends HookConsumerWidget {
  const DownloadedMangaScreen({
    super.key,
    required this.mangaId,
  });

  final int mangaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = downloadedMangaChaptersProvider(mangaId);
    final downloadedChapters = ref.watch(provider);
    final selectedChapters = useState<Map<int, ChapterDto>>({});
    final chapters = sortDownloadedMangaChapters(
      downloadedChapters.valueOrNull ?? const [],
    );

    Future<void> refresh() async {
      ref.invalidate(provider);
      await ref.read(provider.future);
    }

    void toggleSelection(ChapterDto chapter) {
      selectedChapters.value =
          selectedChapters.value.toggleKey(chapter.id, chapter);
    }

    return PopScope(
      canPop: selectedChapters.value.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          selectedChapters.value = {};
        }
      },
      child: Scaffold(
        appBar: selectedChapters.value.isNotEmpty
            ? AppBar(
                leading: IconButton(
                  tooltip: context.l10n.close,
                  onPressed: () => selectedChapters.value = {},
                  icon: const Icon(Icons.close_rounded),
                ),
                title: Text(
                  context.l10n.numSelected(selectedChapters.value.length),
                ),
                actions: [
                  IconButton(
                    tooltip: context.l10n.selectAll,
                    onPressed: () => selectedChapters.value = {
                      for (final chapter in chapters) chapter.id: chapter,
                    },
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                  IconButton(
                    tooltip: context.l10n.invertSelection,
                    onPressed: () => selectedChapters.value = {
                      for (final chapter in chapters)
                        if (!selectedChapters.value.containsKey(chapter.id))
                          chapter.id: chapter,
                    },
                    icon: const Icon(Icons.flip_to_back_rounded),
                  ),
                ],
              )
            : AppBar(
                title: Text(context.l10n.downloaded),
              ),
        bottomSheet: selectedChapters.value.isEmpty
            ? null
            : DownloadedChaptersDeleteBar(
                mangaId: mangaId,
                selectedChapters: selectedChapters,
              ),
        body: downloadedChapters.showUiWhenData(
          context,
          (data) {
            final sortedChapters = sortDownloadedMangaChapters(data);
            if (sortedChapters.isEmpty) {
              return Emoticons(
                title: context.l10n.noChaptersFound,
              );
            }
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: selectedChapters.value.isEmpty ? 16 : 80,
                ),
                itemCount: sortedChapters.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final manga = sortedChapters.first.manga;
                    return _DownloadedMangaHeader(
                      manga: manga,
                      onTap: () => MangaRoute(mangaId: manga.id).push(context),
                    );
                  }

                  final chapter = sortedChapters[index - 1];
                  final isSelected =
                      selectedChapters.value.containsKey(chapter.id);
                  return GestureDetector(
                    onSecondaryTap: () => toggleSelection(chapter),
                    child: ListTile(
                      key: ValueKey('downloaded-chapter-${chapter.id}'),
                      title: Text(
                        chapter.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: chapter.scanlator.isNotBlank
                          ? Text(
                              chapter.scanlator!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: const Icon(Icons.download_done_rounded),
                      selected: isSelected,
                      selectedColor: context.theme.colorScheme.onSurface,
                      selectedTileColor: context.isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      onTap: selectedChapters.value.isNotEmpty
                          ? () => toggleSelection(chapter)
                          : () => ReaderRoute(
                                mangaId: mangaId,
                                chapterId: chapter.id,
                                showReaderLayoutAnimation: true,
                              ).push(context),
                      onLongPress: () => toggleSelection(chapter),
                    ),
                  );
                },
              ),
            );
          },
          showGenericError: true,
          refresh: () => ref.invalidate(provider),
        ),
      ),
    );
  }
}

class _DownloadedMangaHeader extends StatelessWidget {
  const _DownloadedMangaHeader({
    required this.manga,
    required this.onTap,
  });

  final MangaBaseDto manga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: KEdgeInsets.h16v8.size,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('downloaded-manga-header-${manga.id}'),
        onTap: onTap,
        child: Padding(
          padding: KEdgeInsets.a8.size,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: KBorderRadius.r8.radius,
                child: manga.thumbnailUrl.isNotBlank
                    ? ServerImage(
                        imageUrl: manga.thumbnailUrl!,
                        size: const Size(60, 80),
                      )
                    : const SizedBox(
                        width: 60,
                        height: 80,
                        child: Icon(Icons.menu_book_rounded),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  manga.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
