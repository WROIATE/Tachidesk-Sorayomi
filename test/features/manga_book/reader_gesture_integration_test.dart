import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_interactive_viewer.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_page_gesture_handler.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_wrapper.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';

void main() {
  for (final layout in [
    ReaderNavigationLayout.rightAndLeft,
    ReaderNavigationLayout.edge,
    ReaderNavigationLayout.kindlish,
    ReaderNavigationLayout.lShaped,
  ]) {
    for (final reverse in [false, true]) {
      for (final showHint in [false, true]) {
        testWidgets('fresh reader edge swipe: $layout $reverse hint=$showHint',
            (tester) async {
          final harness = await _pumpReader(tester,
              reverse: reverse,
              layout: layout,
              showHint: showHint,
              settle: false);
          final start = Offset(reverse ? 40 : 760, 300);
          await tester.timedDragFrom(start, Offset(reverse ? 500 : -500, 0),
              const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 800));
          expect(harness.pager.page, 1,
              reason: 'Edge paging must work before the two-second hint ends');
          await tester.tapAt(start);
          await tester.pump(const Duration(milliseconds: 350));
          expect(harness.navigationTaps, 1,
              reason: 'The hint must preserve navigation tap zones');
          await tester.pumpAndSettle();
        });
      }
    }
  }

  for (final advanced in [false, true]) {
    for (final reverse in [false, true]) {
      testWidgets('full reader pans a zoomed image: $advanced $reverse',
          (tester) async {
        final harness = await _pumpReader(tester,
            advanced: advanced, reverse: reverse, zoomed: true);
        final before = harness.transforms[0]![12];
        final gesture = await tester.startGesture(const Offset(400, 300));
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump();
        expect(harness.transforms[0]![12], lessThan(before));
        expect(harness.pager.page, 0);
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('full reader turns pages without zoom: $advanced $reverse',
          (tester) async {
        final harness =
            await _pumpReader(tester, advanced: advanced, reverse: reverse);
        final sign = reverse ? 1.0 : -1.0;
        final gesture =
            await tester.startGesture(Offset(reverse ? 150 : 650, 300));
        await gesture.moveBy(Offset(50 * sign, 0));
        await tester.pump();
        await gesture.moveBy(Offset(450 * sign, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(harness.pager.page, 1);
      });

      testWidgets(
          'full reader pans to an edge then turns one page: $advanced $reverse',
          (tester) async {
        final harness = await _pumpReader(tester,
            advanced: advanced, reverse: reverse, zoomed: true);
        final sign = reverse ? 1.0 : -1.0;
        final gesture = await tester.startGesture(const Offset(400, 300));
        for (final distance in [20.0, 80.0, 80.0, 400.0, 450.0]) {
          await gesture.moveBy(Offset(distance * sign, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(harness.pager.page, 1);
        expect(harness.transforms[0]!.getMaxScaleOnAxis(), 2);
        expect(harness.transforms[1]!.getMaxScaleOnAxis(), 1);
      });
    }
  }

  for (final x in [50.0, 400.0, 750.0]) {
    testWidgets('page double tap wins over navigation zones at $x',
        (tester) async {
      final harness = await _pumpReader(tester);
      await _doubleTap(tester, Offset(x, 300));
      expect(harness.transforms[0]!.getMaxScaleOnAxis(), 2);
      expect(harness.transforms[1]!.getMaxScaleOnAxis(), 1);
      expect(harness.navigationTaps, 0);
      await tester.longPressAt(Offset(x, 300));
      await tester.pumpAndSettle();
      expect(harness.longPresses, 1);
      await _doubleTap(tester, Offset(x, 300));
      expect(harness.transforms[0]!.getMaxScaleOnAxis(), 1);
      final gesture = await tester.startGesture(const Offset(650, 300));
      await gesture.moveBy(const Offset(-25, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(-450, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(harness.pager.page, 1,
          reason: 'zooming out must return gesture ownership to the pager');
    });
  }

  testWidgets('a double tap spanning two pages does not zoom either page',
      (tester) async {
    final harness = await _pumpReader(tester);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 80));
    harness.pager.jumpToPage(1);
    await tester.pump();
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(harness.transforms[0]!.getMaxScaleOnAxis(), 1);
    expect(harness.transforms[1]!.getMaxScaleOnAxis(), 1);
  });

  testWidgets('full reader pinch zoom does not turn pages', (tester) async {
    final harness = await _pumpReader(tester);
    final first = await tester.startGesture(const Offset(350, 300), pointer: 1);
    final second =
        await tester.startGesture(const Offset(450, 300), pointer: 2);
    await tester.pump();
    await first.moveTo(const Offset(300, 300));
    await second.moveTo(const Offset(500, 300));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(harness.transforms[0]!.getMaxScaleOnAxis(), 2);
    expect(harness.pager.page, 0);
    expect(harness.navigationTaps, 0);
    expect(harness.transforms[1]!.getMaxScaleOnAxis(), 1);
  });
}

Future<void> _doubleTap(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

class _Harness {
  final pager = PageController();
  final transforms = <int, Matrix4>{};
  int navigationTaps = 0;
  int longPresses = 0;
}

Future<_Harness> _pumpReader(
  WidgetTester tester, {
  bool advanced = false,
  bool reverse = false,
  bool zoomed = false,
  ReaderNavigationLayout layout = ReaderNavigationLayout.rightAndLeft,
  bool showHint = false,
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final harness = _Harness();
  addTearDown(harness.pager.dispose);
  var locked = zoomed;
  var settledIndex = 0;
  final zoom = Matrix4.identity()
    ..[0] = 2
    ..[5] = 2
    ..[12] = -400
    ..[13] = -300;
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    child: MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      return ReaderView(
        toggleVisibility: () {},
        onLongPress: () => harness.longPresses++,
        scrollDirection: Axis.horizontal,
        mangaId: 1,
        mangaReaderPadding: 0,
        onNext: () => harness.navigationTaps++,
        onPrevious: () => harness.navigationTaps++,
        prevNextChapterPair: null,
        mangaReaderNavigationLayout: layout,
        showReaderLayoutAnimation: showHint,
        readerSwipeChapterToggle: !advanced,
        lastPageSwipeEnabled: advanced,
        resolvedReaderMode: reverse
            ? ReaderMode.singleHorizontalRTL
            : ReaderMode.singleHorizontalLTR,
        currentIndex: settledIndex,
        chapterPages: Fragment$ChapterPagesDto(
          chapter: Fragment$ChapterPagesDto$chapter(id: 1, pageCount: 3),
          pages: const ['a', 'b', 'c'],
        ),
        pageController: harness.pager,
        interactionLocked: locked,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            final page = harness.pager.page!;
            if ((page - page.round()).abs() < .001) {
              setState(() {
                settledIndex = page.round();
                locked =
                    (harness.transforms[settledIndex]?.getMaxScaleOnAxis() ??
                            1) >
                        1.001;
              });
            }
            return false;
          },
          child: ReaderPageGestureHandler(
            controller: harness.pager,
            scrollDirection: Axis.horizontal,
            child: PageView.builder(
              controller: harness.pager,
              reverse: reverse,
              allowImplicitScrolling: true,
              physics: locked
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: 3,
              itemBuilder: (_, index) => ReaderInteractiveViewer(
                key: ValueKey(index),
                enabled: true,
                resetToken: 1,
                initialTransform: harness.transforms[index] ??
                    (zoomed && index == 0 ? zoom : null),
                pageController: harness.pager,
                onInteractionLockChanged: (value) {
                  if (settledIndex == index) setState(() => locked = value);
                },
                onTransformChanged: (value) =>
                    harness.transforms[index] = Matrix4.copy(value),
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      );
    })),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return harness;
}
