import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/manga_details/manga_details_screen.dart';
import 'package:tachidesk_sorayomi/src/graphql/__generated__/schema.graphql.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/widgets/manga_cover/list/manga_cover_descriptive_list_tile.dart';

void main() {
  test('chapter list clears the floating action button and safe area', () {
    expect(
      calculateChapterListBottomPadding(
        hasFloatingActionButton: true,
        bottomSafeArea: 24,
      ),
      96,
    );
  });

  test('chapter list keeps minimum spacing without the button', () {
    expect(
      calculateChapterListBottomPadding(
        hasFloatingActionButton: false,
        bottomSafeArea: 24,
      ),
      56,
    );
    expect(
      calculateChapterListBottomPadding(
        hasFloatingActionButton: false,
        bottomSafeArea: 64,
      ),
      64,
    );
  });

  testWidgets('details title is fully shown and keeps its search action', (
    tester,
  ) async {
    const title = '光是和你当青梅竹马就够烦的了！'
        '～从绝交开始，与S级美少女一同展开的校园逆袭生活～';
    var searchedTitle = '';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MangaCoverDescriptiveListTile(
              manga: _manga(title),
              showFullTitle: true,
              showBadges: false,
              onTitleClicked: (query) => searchedTitle = query,
            ),
          ),
        ),
      ),
    );

    final titleFinder = find.text(title);
    expect(tester.widget<Text>(titleFinder).maxLines, isNull);
    expect(tester.widget<Text>(titleFinder).overflow, isNull);
    expect(
      find.byKey(const ValueKey('manga-title-expand-button')),
      findsNothing,
    );

    await tester.tap(titleFinder);
    expect(searchedTitle, title);
  });

  testWidgets('descriptive lists keep the two-line title by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MangaCoverDescriptiveListTile(
              manga: _manga('这是一个超过两行后应当继续保持省略显示的书架列表漫画标题'),
              showBadges: false,
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.text('这是一个超过两行后应当继续保持省略显示的书架列表漫画标题'),
    );
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(
      find.byKey(const ValueKey('manga-title-expand-button')),
      findsNothing,
    );
  });

  testWidgets('details split authors and artists into separate searches', (
    tester,
  ) async {
    final searchedNames = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MangaCoverDescriptiveListTile(
              manga: _manga(
                '漫画',
                author: '作者甲，作者乙',
                artist: '画师甲, 画师乙',
              ),
              showFullTitle: true,
              showArtist: true,
              showBadges: false,
              onTitleClicked: searchedNames.add,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.brush_rounded), findsOneWidget);

    final displayedNames = {
      '作者甲,': '作者甲',
      '作者乙': '作者乙',
      '画师甲,': '画师甲',
      '画师乙': '画师乙',
    };
    for (final entry in displayedNames.entries) {
      expect(find.text(entry.key), findsOneWidget);
      await tester.tap(find.text(entry.key));
    }

    expect(searchedNames, displayedNames.values);
    expect(find.text(', '), findsNothing);
  });
}

Fragment$MangaDto _manga(
  String title, {
  String? author = '作者',
  String? artist,
}) =>
    Fragment$MangaDto(
      author: author,
      artist: artist,
      downloadCount: 0,
      genre: const [],
      id: 1,
      inLibrary: false,
      inLibraryAt: '0',
      initialized: true,
      meta: const [],
      sourceId: '1',
      status: Enum$MangaStatus.UNKNOWN,
      title: title,
      unreadCount: 0,
      updateStrategy: Enum$UpdateStrategy.ALWAYS_UPDATE,
      url: '',
    );
