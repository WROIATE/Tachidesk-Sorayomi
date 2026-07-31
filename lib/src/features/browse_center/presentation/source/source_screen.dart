// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/language_list.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../../widgets/emoticons.dart';
import 'controller/source_controller.dart';
import 'widgets/source_list_tile.dart';

class SourceScreen extends HookConsumerWidget {
  const SourceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceMapData = ref.watch(sourceMapFilteredProvider);
    final pinnedSourceIds = ref.watch(pinnedSourceIdsProvider);
    final sourceSections = buildSourceSectionsForDisplay(
      {...?sourceMapData.valueOrNull},
      {...?pinnedSourceIds},
    );

    refresh() => ref.refresh(sourceListProvider.future);
    useEffect(() {
      if (sourceMapData.isNotLoading) refresh();
      return;
    }, []);

    useEffect(() {
      sourceMapData.showToastOnError(
        ref.read(toastProvider),
        withMicrotask: true,
      );
      return;
    }, [sourceMapData.valueOrNull]);

    return sourceMapData.showUiWhenData(
      context,
      (data) {
        if (sourceSections.isEmpty) {
          return Emoticons(
            title: context.l10n.noSourcesFound,
            button: TextButton(
              onPressed: refresh,
              child: Text(context.l10n.refresh),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            slivers: [
              for (final section in sourceSections.entries) ...[
                SliverToBoxAdapter(
                  child: ListTile(
                    title: Text(
                      section.key == pinnedSourceGroupKey
                          ? context.l10n.pinnedSources
                          : languageMap[section.key]?.displayName ??
                              section.key,
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SourceListTile(
                      source: section.value[index],
                    ),
                    childCount: section.value.length,
                  ),
                )
              ],
            ],
          ),
        );
      },
      refresh: refresh,
    );
  }
}
