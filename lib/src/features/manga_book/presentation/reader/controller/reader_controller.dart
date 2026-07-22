// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/manga_book/manga_book_repository.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/chapter_page/chapter_page_model.dart';

part 'reader_controller.g.dart';

@riverpod
FutureOr<ChapterDto?> chapter(
  Ref ref, {
  required int chapterId,
}) =>
    ref.watch(mangaBookRepositoryProvider).getChapter(chapterId: chapterId);

@riverpod
Future<ChapterPagesDto?> chapterPages(Ref ref, {required int chapterId}) async {
  final repository = ref.watch(mangaBookRepositoryProvider);
  final chapterPages =
      await repository.getChapterPages(chapterId: chapterId);

  if (chapterPages == null || chapterPages.pages.isNotEmpty) {
    return chapterPages;
  }

  // The server can return an empty list while preparing uncached pages.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return repository.getChapterPages(chapterId: chapterId);
}
