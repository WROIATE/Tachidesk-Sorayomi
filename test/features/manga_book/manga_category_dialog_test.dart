import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tachidesk_sorayomi/src/features/library/domain/category/category_model.dart';
import 'package:tachidesk_sorayomi/src/features/library/presentation/category/controller/edit_category_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/manga_details/controller/manga_details_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/manga_details/widgets/edit_manga_category_dialog.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/widgets/custom_circular_progress_indicator.dart';

void main() {
  testWidgets('category dialog only shows its heading and stays compact',
      (tester) async {
    final selectedCategories = Completer<Map<String, CategoryDto>?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryControllerProvider.overrideWith(
            _LoadedCategoryController.new,
          ),
          mangaCategoryListProvider(1).overrideWith(
            () => _LoadingMangaCategoryList(selectedCategories.future),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditMangaCategoryDialog(mangaId: 1),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Edit Category'), findsOneWidget);
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).title,
      isA<Text>(),
    );
    final loading = find.byKey(
      const ValueKey('manga-category-dialog-loading'),
    );
    expect(loading, findsOneWidget);
    expect(tester.getSize(loading).height, 112);
    expect(find.byType(CenterSorayomiShimmerIndicator), findsNothing);

    final loadingDialogHeight = tester.getSize(find.byType(AlertDialog)).height;
    selectedCategories.complete({});
    await tester.pump();
    await tester.pump();

    expect(loading, findsNothing);
    expect(
      tester.getSize(find.byType(AlertDialog)).height,
      loadingDialogHeight,
    );
  });
}

class _LoadedCategoryController extends CategoryController {
  @override
  Future<List<CategoryDto>?> build() async => [
        _category(id: 0, name: 'Default'),
        _category(id: 1, name: 'Action'),
        _category(id: 2, name: 'Comedy'),
      ];
}

class _LoadingMangaCategoryList extends MangaCategoryList {
  _LoadingMangaCategoryList(this.selectedCategories);

  final Future<Map<String, CategoryDto>?> selectedCategories;

  @override
  FutureOr<Map<String, CategoryDto>?> build(int mangaId) => selectedCategories;
}

CategoryDto _category({required int id, required String name}) =>
    CategoryDto.fromJson({
      'defaultCategory': id == 0,
      'id': id,
      'includeInDownload': 'EXCLUDE',
      'includeInUpdate': 'EXCLUDE',
      'name': name,
      'order': id,
      'mangas': {
        'totalCount': 0,
        '__typename': 'MangaNodeList',
      },
      'meta': const [],
      '__typename': 'CategoryType',
    });
