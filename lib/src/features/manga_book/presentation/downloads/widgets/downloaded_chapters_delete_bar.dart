// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/misc/toast/toast.dart';
import '../../../data/manga_book/manga_book_repository.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../controller/downloads_controller.dart';

class DownloadedChaptersDeleteBar extends ConsumerWidget {
  const DownloadedChaptersDeleteBar({
    super.key,
    required this.mangaId,
    required this.selectedChapters,
  });

  final int mangaId;
  final ValueNotifier<Map<int, ChapterDto>> selectedChapters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: KEdgeInsets.a8.size,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: context.l10n.delete,
              icon: const Icon(Icons.delete_rounded),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.deleteCategoryTitle),
                    content: Text(
                      context.l10n.nChapters(selectedChapters.value.length),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.delete),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) {
                  return;
                }

                final result = await AsyncValue.guard(
                  () => ref
                      .read(mangaBookRepositoryProvider)
                      .deleteChapters(selectedChapters.value.keys.toList()),
                );
                if (!context.mounted) {
                  return;
                }
                result.showToastOnError(ref.read(toastProvider));
                if (result.hasError) {
                  return;
                }

                selectedChapters.value = {};
                ref.invalidate(downloadedChaptersProvider);
                final provider = downloadedMangaChaptersProvider(mangaId);
                ref.invalidate(provider);
                final remaining = await ref.read(provider.future);
                if (remaining.isEmpty && context.mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
