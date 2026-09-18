// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../constants/app_constants.dart';
import '../../../../../../constants/db_keys.dart';
import '../../../../../../constants/enum.dart';
import '../../../../../../utils/extensions/cache_manager_extensions.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../../../widgets/server_image.dart';
import '../../../../../settings/presentation/reader/widgets/reader_auto_page_turn/reader_auto_page_turn_settings.dart';
import '../../../../../settings/presentation/reader/widgets/reader_pinch_to_zoom/reader_pinch_to_zoom.dart';
import '../../../../../settings/presentation/reader/widgets/reader_scroll_animation_tile/reader_scroll_animation_tile.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../reader_interactive_viewer.dart';
import '../reader_page_gesture_handler.dart';
import '../reader_wrapper.dart';

const Duration _autoPageTurnFadeDuration = Duration(milliseconds: 250);

class SinglePageReaderMode extends HookConsumerWidget {
  const SinglePageReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    required this.initialPage,
    this.onPageChanged,
    this.reverse = false,
    this.scrollDirection = Axis.horizontal,
    this.showReaderLayoutAnimation = false,
  });

  final MangaDto manga;
  final ChapterDto chapter;
  final ValueSetter<int>? onPageChanged;
  final bool reverse;
  final Axis scrollDirection;
  final bool showReaderLayoutAnimation;
  final ChapterPagesDto chapterPages;
  final int initialPage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheManager = useMemoized(() => DefaultCacheManager());
    final scrollController = usePageController(initialPage: initialPage);
    final currentIndex = useState(scrollController.initialPage);
    final isZoomInteractionLocked = useState(false);
    final zoomControllers = useMemoized(
      () => <int, ReaderInteractiveViewerController>{},
      [chapter.id],
    );
    final pageTransforms = useMemoized(
      () => <int, Matrix4>{},
      [chapter.id],
    );
    final pageAspectRatios = useRef(<int, double>{});
    final pageFilePaths = useRef(<int, String>{});
    final currentPageAspectRatio = useState<double?>(null);
    final currentPageFilePath = useState<String?>(null);

    useEffect(() {
      pageAspectRatios.value.clear();
      pageFilePaths.value.clear();
      currentPageAspectRatio.value = null;
      currentPageFilePath.value = null;
      return null;
    }, [chapter.id]);

    useEffect(() {
      currentPageAspectRatio.value = pageAspectRatios.value[currentIndex.value];
      currentPageFilePath.value = pageFilePaths.value[currentIndex.value];
      isZoomInteractionLocked.value =
          _isZoomedTransform(pageTransforms[currentIndex.value]);
      return null;
    }, [chapter.id, currentIndex.value]);

    useEffect(() {
      int currentPage = currentIndex.value;
      // Only prefetch if we have pages data
      if (chapterPages.pages.isNotEmpty) {
        // Prev page
        if (currentPage > 0 && currentPage - 1 < chapterPages.pages.length) {
          cacheManager.getServerFile(ref, chapterPages.pages[currentPage - 1]);
        }
        // Next page
        if (currentPage < (chapterPages.pages.length - 1)) {
          cacheManager.getServerFile(ref, chapterPages.pages[currentPage + 1]);
        }
        // 2nd next page
        if (currentPage < (chapterPages.pages.length - 2)) {
          cacheManager.getServerFile(ref, chapterPages.pages[currentPage + 2]);
        }
      }
      return null;
    }, [currentIndex.value, chapterPages.pages.length]);
    final isAnimationEnabled =
        ref.read(readerScrollAnimationProvider).ifNull(true);
    final isPinchToZoomEnabled = !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        ref.watch(pinchToZoomProvider).ifNull(true);
    final autoPageTurnInterval =
        (ref.watch(readerAutoPageTurnIntervalProvider) ??
                DBKeys.autoPageTurnInterval.initial as double)
            .clamp(0.5, 60)
            .toDouble();
    final autoPageTurnTransition =
        ref.watch(readerAutoPageTurnTransitionProvider) ??
            DBKeys.autoPageTurnTransition.initial as AutoPageTurnTransition;
    final autoPageTurnActive = useState(false);
    final autoPageTurnOpacity = useState(1.0);
    final autoPageTurnCrossFadeTarget = useState<int?>(null);
    final autoPageTurnCrossFadeOpacity = useState(0.0);

    Future<void> previousPage() => scrollController.previousPage(
          duration: isAnimationEnabled ? kDuration : kInstantDuration,
          curve: kCurve,
        );

    Future<void> nextPage() => scrollController.nextPage(
          duration: isAnimationEnabled ? kDuration : kInstantDuration,
          curve: kCurve,
        );

    void clearAutoPageTurnCrossFade() {
      autoPageTurnCrossFadeTarget.value = null;
      autoPageTurnCrossFadeOpacity.value = 0;
    }

    useEffect(() {
      final sourceIndex = currentIndex.value;
      final nextIndex = sourceIndex + 1;
      if (!autoPageTurnActive.value ||
          isZoomInteractionLocked.value ||
          nextIndex >= chapterPages.pages.length) {
        return null;
      }

      final timer = Timer(
        Duration(milliseconds: (autoPageTurnInterval * 1000).round()),
        () async {
          if (!context.mounted || !scrollController.hasClients) return;

          switch (autoPageTurnTransition) {
            case AutoPageTurnTransition.smooth:
              await scrollController.animateToPage(
                nextIndex,
                duration: kDuration,
                curve: Curves.easeInOutCubic,
              );
              break;
            case AutoPageTurnTransition.fade:
              autoPageTurnOpacity.value = 0;
              await Future<void>.delayed(_autoPageTurnFadeDuration);
              if (!context.mounted) return;
              if (!autoPageTurnActive.value ||
                  isZoomInteractionLocked.value ||
                  currentIndex.value != sourceIndex ||
                  !scrollController.hasClients) {
                autoPageTurnOpacity.value = 1;
                return;
              }
              scrollController.jumpToPage(nextIndex);
              autoPageTurnOpacity.value = 1;
              break;
            case AutoPageTurnTransition.crossFade:
              autoPageTurnCrossFadeTarget.value = nextIndex;
              await WidgetsBinding.instance.endOfFrame;
              if (!context.mounted) return;
              if (!autoPageTurnActive.value ||
                  isZoomInteractionLocked.value ||
                  currentIndex.value != sourceIndex ||
                  !scrollController.hasClients) {
                clearAutoPageTurnCrossFade();
                return;
              }
              autoPageTurnCrossFadeOpacity.value = 1;
              await Future<void>.delayed(_autoPageTurnFadeDuration);
              if (!context.mounted) return;
              if (!autoPageTurnActive.value ||
                  isZoomInteractionLocked.value ||
                  currentIndex.value != sourceIndex ||
                  !scrollController.hasClients) {
                clearAutoPageTurnCrossFade();
                return;
              }
              scrollController.jumpToPage(nextIndex);
              clearAutoPageTurnCrossFade();
              break;
          }
        },
      );
      return timer.cancel;
    }, [
      autoPageTurnActive.value,
      autoPageTurnInterval,
      autoPageTurnTransition,
      chapterPages.pages.length,
      currentIndex.value,
      isZoomInteractionLocked.value,
    ]);

    return ReaderWrapper(
      scrollDirection: scrollDirection,
      chapter: chapter,
      manga: manga,
      chapterPages: chapterPages,
      currentIndex: currentIndex.value,
      onChanged: (index) => scrollController.jumpToPage(index),
      showReaderLayoutAnimation: showReaderLayoutAnimation,
      onPrevious: previousPage,
      onNext: nextPage,
      pageController: scrollController,
      interactionLocked: isZoomInteractionLocked.value,
      onDoubleTap: (position) =>
          zoomControllers[currentIndex.value]?.toggleZoomAt(position),
      currentPageFilePath: currentPageFilePath.value,
      readerAction: IconButton(
        key: const ValueKey('auto-page-turn-toggle'),
        tooltip: autoPageTurnActive.value
            ? context.l10n.pauseAutoPageTurn
            : context.l10n.startAutoPageTurn,
        onPressed: chapterPages.pages.length > 1 &&
                (autoPageTurnActive.value ||
                    currentIndex.value < chapterPages.pages.length - 1)
            ? () {
                autoPageTurnActive.value = !autoPageTurnActive.value;
                if (!autoPageTurnActive.value) {
                  autoPageTurnOpacity.value = 1;
                  clearAutoPageTurnCrossFade();
                }
              }
            : null,
        icon: Icon(
          autoPageTurnActive.value
              ? Icons.pause_circle_outline_rounded
              : Icons.play_circle_outline_rounded,
        ),
      ),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            final page = scrollController.page;
            // Catching an animation with hold() also emits ScrollEnd. Do not
            // save a page or rebuild the reader while between two pages.
            if (page == null || (page - page.round()).abs() > 0.001) {
              return false;
            }
            final settledPage = page.round();
            if (settledPage != currentIndex.value) {
              currentIndex.value = settledPage;
              onPageChanged?.call(settledPage);
              if (settledPage >= chapterPages.pages.length - 1) {
                autoPageTurnActive.value = false;
              }
            }
          }
          return false;
        },
        child: IgnorePointer(
          ignoring: autoPageTurnOpacity.value != 1 ||
              autoPageTurnCrossFadeTarget.value != null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                key: const ValueKey('auto-page-turn-fade'),
                opacity: autoPageTurnOpacity.value,
                duration: _autoPageTurnFadeDuration,
                curve: Curves.easeInOut,
                child: ReaderPageGestureHandler(
                  controller: scrollController,
                  scrollDirection: scrollDirection,
                  child: PageView.builder(
                    scrollDirection: scrollDirection,
                    reverse: reverse,
                    controller: scrollController,
                    allowImplicitScrolling: true,
                    physics: isZoomInteractionLocked.value
                        ? const NeverScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                          )
                        : const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    itemBuilder: (context, index) {
                      final zoomController = zoomControllers.putIfAbsent(
                        index,
                        ReaderInteractiveViewerController.new,
                      );
                      return ReaderInteractiveViewer(
                        key: ValueKey('reader-page-zoom-${chapter.id}-$index'),
                        enabled: isPinchToZoomEnabled,
                        resetToken: chapter.id,
                        controller: zoomController,
                        initialTransform: pageTransforms[index],
                        contentAspectRatio: index == currentIndex.value
                            ? currentPageAspectRatio.value
                            : pageAspectRatios.value[index],
                        pageController: scrollController,
                        onTransformChanged: (transform) {
                          if (_isZoomedTransform(transform)) {
                            pageTransforms[index] = Matrix4.copy(transform);
                          } else {
                            pageTransforms.remove(index);
                          }
                        },
                        onInteractionLockChanged: (locked) {
                          if (currentIndex.value == index) {
                            isZoomInteractionLocked.value = locked;
                          }
                        },
                        child: _buildPage(
                          context,
                          index,
                          isAnimationActive: index == currentIndex.value,
                          placeholderAspectRatio: pageAspectRatios.value[index],
                          onAspectRatioResolved: (aspectRatio) {
                            pageAspectRatios.value[index] = aspectRatio;
                            if (currentIndex.value == index) {
                              currentPageAspectRatio.value = aspectRatio;
                            }
                          },
                          onFileResolved: (filePath) {
                            pageFilePaths.value[index] = filePath;
                            if (currentIndex.value == index) {
                              currentPageFilePath.value = filePath;
                            }
                          },
                        ),
                      );
                    },
                    itemCount: chapterPages.pages.isEmpty
                        ? 1
                        : chapterPages.pages.length,
                  ),
                ),
              ),
              if (autoPageTurnCrossFadeTarget.value case final targetIndex?)
                AnimatedOpacity(
                  key: const ValueKey('auto-page-turn-cross-fade'),
                  opacity: autoPageTurnCrossFadeOpacity.value,
                  duration: _autoPageTurnFadeDuration,
                  curve: Curves.easeInOut,
                  child: _buildPage(context, targetIndex),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    int index, {
    bool isAnimationActive = true,
    double? placeholderAspectRatio,
    ValueChanged<double>? onAspectRatioResolved,
    ValueChanged<String>? onFileResolved,
  }) {
    if (chapterPages.pages.isEmpty || index >= chapterPages.pages.length) {
      return const Center(child: CenterSorayomiShimmerIndicator());
    }

    return ServerImage(
      showReloadButton: true,
      fit: BoxFit.contain,
      size: Size.fromHeight(context.height),
      appendApiToUrl: false,
      imageUrl: chapterPages.pages[index],
      preferFlutterCodec: !kIsWeb && Platform.isAndroid,
      isAnimationActive: isAnimationActive,
      evictFromMemoryOnDispose: true,
      placeholderAspectRatio: placeholderAspectRatio,
      onAspectRatioResolved: onAspectRatioResolved,
      onFileResolved: onFileResolved,
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          CenterSorayomiShimmerIndicator(value: downloadProgress.progress),
    );
  }
}

bool _isZoomedTransform(Matrix4? transform) =>
    transform != null && transform.getMaxScaleOnAxis() > 1.001;
