import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/directional_swipe_gesture_handler.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_interactive_viewer.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_navigation_layout/layouts/right_and_left_layout.dart';

void main() {
  testWidgets('double tap toggles focal zoom without triggering a page tap', (
    tester,
  ) async {
    final zoomController = ReaderInteractiveViewerController();
    var interactionLocked = false;
    var pageTapCalls = 0;
    Offset? doubleTapPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: DirectionalSwipeGestureHandler(
          onTap: () => pageTapCalls++,
          onDoubleTapDown: (details) =>
              doubleTapPosition = details.globalPosition,
          onDoubleTap: () => zoomController.toggleZoomAt(doubleTapPosition!),
          onLongPressStart: (_) {},
          onLongPressEnd: (_) {},
          onLongPressMoveUpdate: (_) {},
          scrollDirection: Axis.horizontal,
          readerSwipeChapterToggle: true,
          lastPageSwipeEnabled: false,
          resolvedReaderMode: ReaderMode.singleHorizontalLTR,
          currentIndex: 0,
          chapterPages: _chapterPages,
          mangaId: 1,
          prevNextChapterPair: null,
          onNextPage: () {},
          onPreviousPage: () {},
          pageController: null,
          child: ReaderInteractiveViewer(
            enabled: true,
            resetToken: 0,
            controller: zoomController,
            onInteractionLockChanged: (locked) => interactionLocked = locked,
            child: const ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );

    const focalPoint = Offset(200, 150);
    await _doubleTap(tester, focalPoint);

    final transformationController = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(transformationController.value.getMaxScaleOnAxis(), 2);
    expect(transformationController.value.entry(0, 3), closeTo(-200, 0.01));
    expect(transformationController.value.entry(1, 3), closeTo(-150, 0.01));
    expect(interactionLocked, isTrue);
    expect(pageTapCalls, 0);

    await _doubleTap(tester, focalPoint);

    expect(transformationController.value.getMaxScaleOnAxis(), 1);
    expect(interactionLocked, isFalse);
    expect(pageTapCalls, 0);
  });

  testWidgets('double tap overrides navigation tap zones', (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;
    var zoomCalls = 0;
    Offset? doubleTapPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: RightAndLeftLayout(
          onLeftTap: () => previousCalls++,
          onRightTap: () => nextCalls++,
          onDoubleTapDown: (details) =>
              doubleTapPosition = details.globalPosition,
          onDoubleTap: () {
            expect(doubleTapPosition, isNotNull);
            zoomCalls++;
          },
        ),
      ),
    );

    await _doubleTap(tester, const Offset(50, 300));

    expect(zoomCalls, 1);
    expect(previousCalls, 0);
    expect(nextCalls, 0);
  });

  testWidgets('pinch zoom takes over after a page drag has started', (
    tester,
  ) async {
    final pageController = PageController();
    var interactionLocked = false;
    var currentPage = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => ReaderInteractiveViewer(
            enabled: true,
            resetToken: currentPage,
            onInteractionLockChanged: (locked) {
              interactionLocked = locked;
              setState(() {});
            },
            child: PageView(
              controller: pageController,
              onPageChanged: (page) => setState(() => currentPage = page),
              physics: interactionLocked
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      ),
    );

    await _pinch(
      tester,
      firstStart: const Offset(390, 300),
      firstBeforeSecond: const Offset(370, 300),
      secondStart: const Offset(410, 300),
      firstEnd: const Offset(350, 300),
      secondEnd: const Offset(450, 300),
    );

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    expect(interactionLocked, isTrue);
    expect(pageController.page, 0);

    await _pinch(
      tester,
      firstStart: const Offset(350, 300),
      firstBeforeSecond: const Offset(350, 300),
      secondStart: const Offset(450, 300),
      firstEnd: const Offset(390, 300),
      secondEnd: const Offset(410, 300),
    );

    expect(controller.value.getMaxScaleOnAxis(), 1);
    expect(interactionLocked, isFalse);
    pageController.dispose();
  });

  testWidgets('pinch zoom does not trigger chapter swipe navigation', (
    tester,
  ) async {
    var nextCalls = 0;
    var previousCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DirectionalSwipeGestureHandler(
          onTap: () {},
          onLongPressStart: (_) {},
          onLongPressEnd: (_) {},
          onLongPressMoveUpdate: (_) {},
          scrollDirection: Axis.horizontal,
          readerSwipeChapterToggle: true,
          lastPageSwipeEnabled: false,
          resolvedReaderMode: ReaderMode.singleHorizontalLTR,
          currentIndex: 0,
          chapterPages: _chapterPages,
          mangaId: 1,
          prevNextChapterPair: null,
          onNextPage: () => nextCalls++,
          onPreviousPage: () => previousCalls++,
          pageController: null,
          child: ReaderInteractiveViewer(
            enabled: true,
            resetToken: 0,
            onInteractionLockChanged: (_) {},
            child: const ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );

    await _pinch(
      tester,
      firstStart: const Offset(400, 290),
      firstBeforeSecond: const Offset(400, 270),
      secondStart: const Offset(400, 310),
      firstEnd: const Offset(400, 230),
      secondEnd: const Offset(400, 350),
    );

    expect(nextCalls, 0);
    expect(previousCalls, 0);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
  });

  testWidgets('disabled pinch zoom leaves the reader unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderInteractiveViewer(
          enabled: false,
          resetToken: 0,
          onInteractionLockChanged: _ignoreLockChange,
          child: ColoredBox(key: ValueKey('reader'), color: Colors.red),
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byKey(const ValueKey('reader')), findsOneWidget);
  });

  testWidgets('disabling zoom also disables controller-driven double tap', (
    tester,
  ) async {
    final zoomController = ReaderInteractiveViewerController();
    var enabled = true;
    var interactionLocked = false;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ReaderInteractiveViewer(
              enabled: enabled,
              resetToken: 0,
              controller: zoomController,
              onInteractionLockChanged: (locked) => interactionLocked = locked,
              child: const ColoredBox(color: Colors.red),
            );
          },
        ),
      ),
    );

    rebuild(() => enabled = false);
    await tester.pump();
    zoomController.toggleZoomAt(const Offset(200, 150));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(interactionLocked, isFalse);
  });

  testWidgets('changing pages resets the zoom state', (tester) async {
    var interactionLocked = false;
    var currentPage = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ReaderInteractiveViewer(
              enabled: true,
              resetToken: currentPage,
              onInteractionLockChanged: (locked) {
                interactionLocked = locked;
              },
              child: const ColoredBox(color: Colors.red),
            );
          },
        ),
      ),
    );

    await _pinch(
      tester,
      firstStart: const Offset(390, 300),
      firstBeforeSecond: const Offset(370, 300),
      secondStart: const Offset(410, 300),
      firstEnd: const Offset(350, 300),
      secondEnd: const Offset(450, 300),
    );

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    expect(interactionLocked, isTrue);

    rebuild(() => currentPage++);
    await tester.pump();
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), 1);
    expect(interactionLocked, isFalse);
  });
}

final _chapterPages = Fragment$ChapterPagesDto(
  chapter: Fragment$ChapterPagesDto$chapter(id: 1, pageCount: 1),
  pages: const ['page'],
);

void _ignoreLockChange(bool _) {}

Future<void> _doubleTap(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

Future<void> _pinch(
  WidgetTester tester, {
  required Offset firstStart,
  required Offset firstBeforeSecond,
  required Offset secondStart,
  required Offset firstEnd,
  required Offset secondEnd,
}) async {
  final first = await tester.createGesture(pointer: 1);
  final second = await tester.createGesture(pointer: 2);
  await first.down(firstStart);
  await first.moveTo(firstBeforeSecond);
  await tester.pump();
  await second.down(secondStart);
  await first.moveTo(firstEnd);
  await second.moveTo(secondEnd);
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}
