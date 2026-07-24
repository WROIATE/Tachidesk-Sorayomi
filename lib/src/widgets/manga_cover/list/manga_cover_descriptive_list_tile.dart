// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../constants/app_sizes.dart';
import '../../../constants/enum.dart';
import '../../../features/browse_center/domain/source/source_model.dart';
import '../../../features/manga_book/domain/manga/manga_model.dart';
import '../../../routes/router_config.dart';
import '../../../utils/extensions/custom_extensions.dart';
import '../grid/manga_cover_grid_tile.dart';
import '../widgets/manga_badges.dart';
import '../widgets/manga_chips.dart';

class MangaCoverDescriptiveListTile extends StatelessWidget {
  const MangaCoverDescriptiveListTile({
    super.key,
    required this.manga,
    this.onPressed,
    this.onLongPress,
    this.onTitleClicked,
    this.showBadges = true,
    this.showCountBadges = true,
    this.showFullTitle = false,
    this.showArtist = false,
    this.retryImageAfterFailure,
  });
  static final _contributorSeparator = RegExp(r'[,，]');

  final MangaDto manga;
  final bool showBadges;
  final bool showCountBadges;
  final bool showFullTitle;
  final bool showArtist;
  final Future<void>? retryImageAfterFailure;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onTitleClicked;
  @override
  Widget build(BuildContext context) {
    final authors = (manga.author ?? '')
        .split(_contributorSeparator)
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final artists = (manga.artist ?? '')
        .split(_contributorSeparator)
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final hasDistinctArtists = showArtist &&
        artists.isNotEmpty &&
        manga.artist?.trim() != manga.author?.trim();

    return InkWell(
      onTap: onPressed,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: showFullTitle
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 160,
              child: MangaCoverGridTile(
                manga: manga,
                showBadges: false,
                showTitle: false,
                showDarkOverlay: false,
                retryImageAfterFailure: retryImageAfterFailure,
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onTitleClicked != null
                          ? () => onTitleClicked!(manga.title)
                          : null,
                      child: Text(
                        manga.title,
                        style: context.textTheme.titleLarge,
                        overflow: showFullTitle ? null : TextOverflow.ellipsis,
                        maxLines: showFullTitle ? null : 2,
                        semanticsLabel: manga.title,
                      ),
                    ),
                    Gap(8),
                    if (onTitleClicked == null)
                      Text(
                        authors.isEmpty
                            ? context.l10n.unknownAuthor
                            : authors.join(', '),
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium,
                      )
                    else if (authors.isEmpty)
                      _ContributorNames(
                        names: [context.l10n.unknownAuthor],
                        leadingIcon: Icons.person_outline_rounded,
                      )
                    else
                      _ContributorNames(
                        names: authors,
                        leadingIcon: Icons.person_outline_rounded,
                        onNameClicked: onTitleClicked,
                      ),
                    if (hasDistinctArtists) ...[
                      Gap(4),
                      _ContributorNames(
                        names: artists,
                        leadingIcon: Icons.brush_rounded,
                        onNameClicked: onTitleClicked,
                      ),
                    ],
                    Gap(8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...[
                          Icon(
                            MangaStatus.fromJson(manga.status.name).icon,
                            size: 16,
                            color: context.textTheme.bodySmall?.color,
                          ),
                          Text(
                            " ${MangaStatus.fromJson(manga.status.name).toLocale(context)}",
                            style: context.textTheme.bodySmall,
                          ),
                        ],
                        if (manga.source?.displayName != null) ...[
                          Text(" • "),
                          InkWell(
                            onTap: (manga.source?.id).isNotBlank
                                ? () => SourceTypeRoute(
                                        sourceId: manga.source!.id,
                                        sourceType: SourceType.POPULAR)
                                    .go(context)
                                : null,
                            child: Text(
                              manga.source?.displayName ??
                                  context.l10n.unknownSource,
                              style: context.textTheme.bodySmall,
                            ),
                          ),
                        ]
                      ],
                    ),
                    // if (showLastReadChapter) ...[
                    //   Padding(
                    //     padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                    //     child: Text(
                    //       manga.lastChapterRead?.name ?? "",
                    //       overflow: TextOverflow.ellipsis,
                    //       style: context.textTheme.bodySmall,
                    //     ),
                    //   ),
                    //   Padding(
                    //     padding: const EdgeInsets.symmetric(vertical: 2.0),
                    //     child: Text(
                    //       manga.lastReadAt.toDaysAgoFromSeconds ?? "",
                    //       overflow: TextOverflow.ellipsis,
                    //       style: context.textTheme.bodySmall,
                    //     ),
                    //   ),
                    // ],
                    if (showBadges)
                      context.isTablet
                          ? MangaChipsRow(
                              manga: manga,
                              showCountBadges: showCountBadges,
                            )
                          : MangaBadgesRow(
                              padding: KEdgeInsets.v8.size,
                              manga: manga,
                              showCountBadges: showCountBadges,
                            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributorNames extends StatelessWidget {
  const _ContributorNames({
    required this.names,
    required this.leadingIcon,
    this.onNameClicked,
  });

  final List<String> names;
  final IconData leadingIcon;
  final ValueChanged<String>? onNameClicked;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodyMedium;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < names.length; index++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index == 0) ...[
                Icon(
                  leadingIcon,
                  size: 16,
                  color: style?.color,
                ),
                Gap(4),
              ],
              InkWell(
                onTap: onNameClicked == null
                    ? null
                    : () => onNameClicked!(names[index]),
                child: Text(
                  index < names.length - 1 ? '${names[index]},' : names[index],
                  style: style,
                ),
              ),
              if (index < names.length - 1) Gap(4),
            ],
          ),
      ],
    );
  }
}
