// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/enum.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/logger/logger.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../history/presentation/history_controller.dart';
import '../../../settings/presentation/reader/widgets/reader_ignore_safe_area_tile/reader_ignore_safe_area_tile.dart';
import '../../../settings/presentation/reader/widgets/reader_mode_tile/reader_mode_tile.dart';
import '../../data/manga_book/manga_book_repository.dart';
import '../../domain/manga/manga_model.dart';
import '../manga_details/controller/manga_details_controller.dart';
import 'controller/reader_controller.dart';
import 'utils/reader_initial_page.dart';
import 'utils/reader_progress.dart';
import 'widgets/reader_mode/continuous_reader_mode.dart';
import 'widgets/reader_mode/single_page_reader_mode.dart';

class ReaderScreen extends HookConsumerWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    this.startAtEnd = false,
    this.startAtBeginning = false,
    this.showReaderLayoutAnimation = false,
  });
  final int mangaId;
  final int chapterId;
  final bool startAtEnd;
  final bool startAtBeginning;
  final bool showReaderLayoutAnimation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaProvider = mangaWithIdProvider(mangaId: mangaId);
    final chapterProviderWithIndex = chapterProvider(chapterId: chapterId);
    final chapterPages = ref.watch(chapterPagesProvider(chapterId: chapterId));
    final manga = ref.watch(mangaProvider);
    final chapter = ref.watch(chapterProviderWithIndex);
    final defaultReaderMode = ref.watch(readerModeKeyProvider);
    final ignoreSafeArea = ref.watch(readerIgnoreSafeAreaProvider).ifNull();
    final repository = ref.watch(mangaBookRepositoryProvider);
    final toast = ref.read(toastProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final isExiting = useRef(false);

    final progressSaver = useMemoized(
      () => ReaderProgressSaver(
        save: (progress) async {
          final result = await AsyncValue.guard(
            () => repository.putChapter(
              chapterId: chapterId,
              patch: progress.toChapterChange(),
            ),
          );
          if (result.hasError) {
            if (context.mounted) {
              result.showToastOnError(toast);
            } else {
              logger.e(
                result.error,
                stackTrace: result.stackTrace,
              );
            }
            return;
          }
          container.invalidate(readingHistoryProvider);
          if (isExiting.value || !context.mounted) {
            container.invalidate(chapterProviderWithIndex);
            container.invalidate(mangaChapterListProvider(mangaId: mangaId));
            container.invalidate(mangaProvider);
          }
        },
      ),
      [chapterId, repository, toast],
    );

    useEffect(
      () => () => unawaited(progressSaver.flush()),
      [progressSaver],
    );

    final onPageChanged = useCallback<AsyncValueSetter<int>>(
      (int index) async {
        final chapterPagesValue = chapterPages.valueOrNull;
        if (chapterPagesValue == null) return;
        final actualPageCount = chapterPagesValue.pages.length;
        if (actualPageCount <= 0) return;

        final pageIndex = index.clamp(0, actualPageCount - 1);
        final progress = ReaderProgressUpdate(
          pageIndex: pageIndex,
          isCompleted: pageIndex == actualPageCount - 1,
        );
        if (progress.isCompleted) {
          await progressSaver.saveImmediately(progress);
        } else {
          progressSaver.schedule(progress);
        }
      },
      [chapterPages.valueOrNull, progressSaver],
    );

    useEffect(() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return () => SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
    }, []);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          isExiting.value = true;
          ref.invalidate(chapterProviderWithIndex);
          ref.invalidate(mangaChapterListProvider(mangaId: mangaId));
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SafeArea(
          top: !ignoreSafeArea,
          bottom: !ignoreSafeArea,
          left: !ignoreSafeArea,
          right: !ignoreSafeArea,
          child: manga.showUiWhenData(
            context,
            (data) {
              if (data == null) return const SizedBox.shrink();
              return chapter.showUiWhenData(
                context,
                (chapterData) {
                  if (chapterData == null) return const SizedBox.shrink();
                  return chapterPages.showUiWhenData(
                    context,
                    (chapterPagesData) {
                      if (chapterPagesData == null) {
                        return const SizedBox.shrink();
                      }
                      final initialPage = resolveInitialReaderPage(
                        startAtEnd: startAtEnd,
                        startAtBeginning: startAtBeginning,
                        isRead: chapterData.isRead,
                        lastPageRead: chapterData.lastPageRead,
                        pageCount: chapterPagesData.pages.length,
                      );
                      return switch (
                          data.metaData.readerMode ?? defaultReaderMode) {
                        ReaderMode.singleVertical => SinglePageReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            scrollDirection: Axis.vertical,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                            initialPage: initialPage,
                          ),
                        ReaderMode.singleHorizontalRTL => SinglePageReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            reverse: true,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                            initialPage: initialPage,
                          ),
                        ReaderMode.continuousHorizontalLTR =>
                          ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            scrollDirection: Axis.horizontal,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                            initialPage: initialPage,
                          ),
                        ReaderMode.continuousHorizontalRTL =>
                          ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                            initialPage: initialPage,
                          ),
                        ReaderMode.singleHorizontalLTR => SinglePageReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            chapterPages: chapterPagesData,
                            initialPage: initialPage,
                          ),
                        ReaderMode.continuousVertical => ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            showSeparator: true,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                            initialPage: initialPage,
                          ),
                        ReaderMode.webtoon => ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                            initialPage: initialPage,
                          ),
                        ReaderMode.defaultReader || null => switch (
                              defaultReaderMode ?? ReaderMode.webtoon) {
                            ReaderMode.singleHorizontalLTR =>
                              SinglePageReaderMode(
                                chapter: chapterData,
                                manga: data,
                                onPageChanged: onPageChanged,
                                chapterPages: chapterPagesData,
                                initialPage: initialPage,
                              ),
                            ReaderMode.singleHorizontalRTL =>
                              SinglePageReaderMode(
                                chapter: chapterData,
                                manga: data,
                                onPageChanged: onPageChanged,
                                reverse: true,
                                showReaderLayoutAnimation:
                                    showReaderLayoutAnimation,
                                chapterPages: chapterPagesData,
                                initialPage: initialPage,
                              ),
                            ReaderMode.singleVertical => SinglePageReaderMode(
                                chapter: chapterData,
                                manga: data,
                                onPageChanged: onPageChanged,
                                scrollDirection: Axis.vertical,
                                showReaderLayoutAnimation:
                                    showReaderLayoutAnimation,
                                chapterPages: chapterPagesData,
                                initialPage: initialPage,
                              ),
                            ReaderMode.continuousHorizontalLTR =>
                              ContinuousReaderMode(
                                chapter: chapterData,
                                manga: data,
                                onPageChanged: onPageChanged,
                                scrollDirection: Axis.horizontal,
                                showReaderLayoutAnimation:
                                    showReaderLayoutAnimation,
                                chapterPages: chapterPagesData,
                                initialPage: initialPage,
                              ),
                            ReaderMode.continuousHorizontalRTL =>
                              ContinuousReaderMode(
                                chapter: chapterData,
                                manga: data,
                                onPageChanged: onPageChanged,
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                showReaderLayoutAnimation:
                                    showReaderLayoutAnimation,
                                chapterPages: chapterPagesData,
                                initialPage: initialPage,
                              ),
                            ReaderMode.continuousVertical =>
                              ContinuousReaderMode(
                                chapter: chapterData,
                                manga: data,
                                onPageChanged: onPageChanged,
                                showSeparator: true,
                                showReaderLayoutAnimation:
                                    showReaderLayoutAnimation,
                                chapterPages: chapterPagesData,
                                initialPage: initialPage,
                              ),
                            ReaderMode.webtoon || _ => ContinuousReaderMode(
                                chapter: chapterData,
                                manga: data,
                                onPageChanged: onPageChanged,
                                showReaderLayoutAnimation:
                                    showReaderLayoutAnimation,
                                chapterPages: chapterPagesData,
                                initialPage: initialPage,
                              ),
                          }
                      };
                    },
                    refresh: () => ref.refresh(
                      chapterPagesProvider(chapterId: chapterId).future,
                    ),
                  );
                },
                refresh: () => ref.refresh(chapterProviderWithIndex.future),
                addScaffoldWrapper: true,
              );
            },
            addScaffoldWrapper: true,
            refresh: () => ref.refresh(mangaProvider.future),
          ),
        ),
      ),
    );
  }
}
