import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../data/downloads/downloads_repository.dart';
import '../../../domain/downloads/downloads_model.dart';
import '../../../domain/downloads/graphql/__generated__/fragment.graphql.dart';
import '../../../domain/downloads_queue/downloads_queue_model.dart';

part 'downloads_controller.g.dart';

@riverpod
Stream<DownloadUpdatesDto?> downloadUpdates(Ref ref) =>
    ref.watch(downloadsRepositoryProvider).downloadStatusSubscription();

@riverpod
Future<DownloadStatusDto?> downloadStatus(Ref ref) =>
    ref.watch(downloadsRepositoryProvider).getDownloadStatus();

@riverpod
class DownloadsMap extends _$DownloadsMap {
  void updateDownloadStatus(Fragment$DownloadUpdatesDto? downloadStatusDto) {
    if (downloadStatusDto?.omittedUpdates == true) {
      ref.invalidate(downloadStatusProvider);
      return;
    }

    final currState = {...?stateOrNull};
    for (final element in [...?downloadStatusDto?.initial]) {
      currState[element.chapter.id] = element;
    }
    for (final element in [...?downloadStatusDto?.updates]) {
      switch (element.type) {
        case DownloadUpdateType.DEQUEUED:
        case DownloadUpdateType.FINISHED:
          currState.remove(element.download.chapter.id);
          break;
        case DownloadUpdateType.QUEUED:
        case DownloadUpdateType.PROGRESS:
        case DownloadUpdateType.POSITION:
        case DownloadUpdateType.PAUSED:
        case DownloadUpdateType.ERROR:
        case DownloadUpdateType.STOPPED:
          currState[element.download.chapter.id] = element.download;
          break;
        case DownloadUpdateType.$unknown:
          throw UnimplementedError();
      }
    }
    if (stateOrNull != null) {
      state = currState;
    }
  }

  @override
  Map<int, DownloadDto> build() {
    ref.listen(downloadUpdatesProvider,
        (_, next) => updateDownloadStatus(next.valueOrNull));
    final downloadStatusDto = ref.watch(downloadStatusProvider).valueOrNull;
    return getStateFromUpdates(downloadStatusDto);
  }

  Map<int, DownloadDto> getStateFromUpdates(
      DownloadStatusDto? downloadStatusDto) {
    final downloadsMap = <int, DownloadDto>{};
    for (final element in [...?downloadStatusDto?.queue]) {
      downloadsMap[element.chapter.id] = element;
    }
    return downloadsMap;
  }

  void reorder(int chapterId, int to) async {
    final downloadStatusDto = await ref
        .read(downloadsRepositoryProvider)
        .reorderDownload(chapterId, to);
    state = getStateFromUpdates(downloadStatusDto);
  }
}

@riverpod
DownloadDto? downloadsFromId(Ref ref, int chapterId) =>
    ref.watch(downloadsMapProvider.select((map) => map[chapterId]));

@riverpod
List<int> downloadsChapterIds(Ref ref) {
  final downloads = ref.watch(downloadsMapProvider).values.toList();
  downloads.sort((a, b) => a.position.compareTo(b.position));
  return downloads.map((d) => d.chapter.id).toList();
}

@riverpod
void downloadStatusWatchdog(Ref ref) {
  final downloads = ref.watch(downloadsMapProvider);
  final downloaderState = ref.watch(downloaderStateProvider).valueOrNull;
  final hasActiveDownloads = downloads.values.any(
    (download) =>
        download.state == DownloadState.QUEUED ||
        download.state == DownloadState.DOWNLOADING,
  );

  if (downloaderState != DownloaderState.STARTED || !hasActiveDownloads) {
    return;
  }

  final timer = Timer(const Duration(seconds: 2), () {
    if (!ref.read(downloadStatusProvider).isLoading) {
      ref.invalidate(downloadStatusProvider);
    }
    if (ref.read(downloadUpdatesProvider).hasError) {
      ref.invalidate(downloadUpdatesProvider);
    }
  });
  ref.onDispose(timer.cancel);
}

@riverpod
AsyncValue<DownloaderState?> downloaderState(Ref ref) {
  final downloadUpdates = ref.watch(downloadUpdatesProvider);
  final downloadStatus = ref.watch(downloadStatusProvider);
  final subscriptionState = downloadUpdates.valueOrNull?.state;
  final snapshotState = downloadStatus.valueOrNull?.state;

  if (subscriptionState != null) return AsyncData(subscriptionState);
  if (snapshotState != null) return AsyncData(snapshotState);
  if (downloadUpdates.hasValue || downloadStatus.hasValue) {
    return const AsyncData(null);
  }
  if (downloadStatus.hasError) {
    return AsyncError(
      downloadStatus.error!,
      downloadStatus.stackTrace ?? StackTrace.current,
    );
  }
  if (downloadUpdates.hasError) {
    return AsyncError(
      downloadUpdates.error!,
      downloadUpdates.stackTrace ?? StackTrace.current,
    );
  }
  return const AsyncLoading();
}

@riverpod
bool showDownloadsFAB(Ref ref) {
  final downloads = ref.watch(downloadUpdatesProvider);
  final downloaderState = ref.watch(downloaderStateProvider).valueOrNull;
  return downloaderState == DownloaderState.STARTED ||
      (downloads.valueOrNull?.updates).isNotBlank &&
          downloads.valueOrNull!.updates.any(
            (element) =>
                element.download.state != DownloadState.ERROR ||
                element.download.tries != 3,
          );
}
