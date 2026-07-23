// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:graphql/client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../global_providers/global_providers.dart';
import '../../../../graphql/__generated__/schema.graphql.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../domain/chapter/chapter_model.dart';
import '../../domain/downloads/downloads_model.dart';
import '../../domain/downloads_queue/downloads_queue_model.dart';
import './graphql/__generated__/query.graphql.dart';

part 'downloads_repository.g.dart';

class DownloadsRepository {
  const DownloadsRepository(this.client, this.subscriptionClient);

  final GraphQLClient client;
  final GraphQLClient subscriptionClient;
  // Downloads
  Future<void> startDownloads() => client.mutate$StartDownloader(
        Options$Mutation$StartDownloader(
          variables: Variables$Mutation$StartDownloader(
            input: Input$StartDownloaderInput(),
          ),
        ),
      );

  Future<void> stopDownloads() => client.mutate$StopDownloader(
        Options$Mutation$StopDownloader(
          variables: Variables$Mutation$StopDownloader(
            input: Input$StopDownloaderInput(),
          ),
        ),
      );
  Future<void> clearDownloads() => client.mutate$ClearDownloader(
        Options$Mutation$ClearDownloader(
          variables: Variables$Mutation$ClearDownloader(
            input: Input$ClearDownloaderInput(),
          ),
        ),
      );

  Future<void> addChaptersBatchToDownloadQueue(List<int> chapterIds) =>
      client.mutate$EnqueueChapterDownloads(
        Options$Mutation$EnqueueChapterDownloads(
          variables: Variables$Mutation$EnqueueChapterDownloads(
            input: Input$EnqueueChapterDownloadsInput(ids: chapterIds),
          ),
        ),
      );

  Future<void> removeChapterFromDownloadQueue(int chapterId) =>
      client.mutate$DequeueChapterDownloads(
        Options$Mutation$DequeueChapterDownloads(
          variables: Variables$Mutation$DequeueChapterDownloads(
            input: Input$DequeueChapterDownloadInput(id: chapterId),
          ),
        ),
      );

  Future<DownloadStatusDto?> reorderDownload(int chapterId, int to) => client
      .mutate$ReorderChapterDownload(
        Options$Mutation$ReorderChapterDownload(
          variables: Variables$Mutation$ReorderChapterDownload(
            input: Input$ReorderChapterDownloadInput(
              chapterId: chapterId,
              to: to,
            ),
          ),
        ),
      )
      .getData((data) => data.reorderChapterDownload?.downloadStatus);

  Stream<DownloadUpdatesDto?> downloadStatusSubscription() => subscriptionClient
      .subscribe$DownloadStatusChanged(
        Options$Subscription$DownloadStatusChanged(
          variables: Variables$Subscription$DownloadStatusChanged(
            input: Input$DownloadChangedInput(maxUpdates: 150),
          ),
        ),
      )
      .getData((data) => data.downloadStatusChanged);

  Future<DownloadStatusDto?> getDownloadStatus() =>
      client.query$GetDownloadStatus().getData((data) => data.downloadStatus);

  Future<List<ChapterWithMangaDto>> getDownloadedChapters({
    int? mangaId,
  }) async {
    const pageSize = 100;
    final downloadedChapters = <ChapterWithMangaDto>[];
    int? after;

    while (true) {
      final page = await client
          .query$GetDownloadedChapterPage(
            Options$Query$GetDownloadedChapterPage(
              fetchPolicy: FetchPolicy.networkOnly,
              variables: Variables$Query$GetDownloadedChapterPage(
                after: after,
                condition: Input$ChapterConditionInput(
                  isDownloaded: true,
                  mangaId: mangaId,
                ),
                first: pageSize,
              ),
            ),
          )
          .getData((data) => data.chapters);

      if (page == null) {
        throw StateError('Downloaded chapters query returned no data');
      }

      downloadedChapters.addAll(page.nodes);
      if (!page.pageInfo.hasNextPage) {
        return downloadedChapters;
      }

      final nextCursor = page.pageInfo.endCursor;
      if (nextCursor == null || nextCursor == after) {
        throw StateError('Downloaded chapters pagination did not advance');
      }
      after = nextCursor;
    }
  }
}

@riverpod
DownloadsRepository downloadsRepository(Ref ref) => DownloadsRepository(
    ref.watch(graphQlClientProvider),
    ref.watch(graphQlSubscriptionClientProvider));
