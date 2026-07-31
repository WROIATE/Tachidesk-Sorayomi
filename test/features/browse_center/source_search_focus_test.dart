import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/data/source_repository/source_repository.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/domain/filter/filter_model.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/domain/manga_page/manga_page.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/domain/source/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/domain/source/source_model.dart';
import 'package:tachidesk_sorayomi/src/features/browse_center/presentation/source_manga_list/source_manga_list_screen.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('prefilled source search does not autofocus', (tester) async {
    await _pumpSourceScreen(
      tester,
      sourceType: SourceType.SEARCH,
      initialQuery: 'blue',
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });

  testWidgets('tapping source search action still autofocuses', (tester) async {
    await _pumpSourceScreen(
      tester,
      sourceType: SourceType.POPULAR,
    );

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });
}

Future<void> _pumpSourceScreen(
  WidgetTester tester, {
  required SourceType sourceType,
  String? initialQuery,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sourceRepositoryProvider.overrideWithValue(_FakeSourceRepository()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourceMangaListScreen(
          sourceId: '1',
          sourceType: sourceType,
          initialQuery: initialQuery,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _FakeSourceRepository extends SourceRepository {
  _FakeSourceRepository()
      : super(
          GraphQLClient(
            link: Link.function((_, [__]) => const Stream.empty()),
            cache: GraphQLCache(),
          ),
        );

  @override
  Future<SourceDto?> getSource(String sourceId) async => Fragment$SourceDto(
        displayName: 'Test Source',
        iconUrl: '',
        id: sourceId,
        isConfigurable: false,
        isNsfw: false,
        lang: 'en',
        name: 'Test Source',
        supportsLatest: false,
        $extension: Fragment$SourceDto$extension(
          pkgName: 'test.extension',
        ),
      );

  @override
  Future<List<Filter>?> getSourceFilter(String sourceId) async => [];

  @override
  Future<MangaPage?> fetchSourceManga({
    required String sourceId,
    required SourceType sourceType,
    required int page,
    String? query,
    List<FilterChange>? filters,
  }) async =>
      null;
}
