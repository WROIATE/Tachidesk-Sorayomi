import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/directional_swipe_gesture_handler.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_interactive_viewer.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_navigation_layout/layouts/right_and_left_layout.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_page_gesture_handler.dart';

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
          onLongPress: () {},
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
          onLongPress: () {},
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

  testWidgets('locked image interaction suppresses outer page swipes', (
    tester,
  ) async {
    var nextCalls = 0;
    var previousCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DirectionalSwipeGestureHandler(
          onTap: () {},
          onLongPress: () {},
          scrollDirection: Axis.horizontal,
          readerSwipeChapterToggle: false,
          lastPageSwipeEnabled: true,
          resolvedReaderMode: ReaderMode.singleHorizontalLTR,
          currentIndex: 0,
          chapterPages: _chapterPages,
          mangaId: 1,
          prevNextChapterPair: null,
          onNextPage: () => nextCalls++,
          onPreviousPage: () => previousCalls++,
          pageController: null,
          interactionLocked: true,
          child: const ColoredBox(
            key: ValueKey('locked-reader-content'),
            color: Colors.red,
          ),
        ),
      ),
    );

    await tester.fling(
      find.byKey(const ValueKey('locked-reader-content')),
      const Offset(-300, 0),
      3000,
    );
    await tester.pumpAndSettle();

    expect(nextCalls, 0);
    expect(previousCalls, 0);
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

  testWidgets('zoomed content stays aligned to the image edges', (
    tester,
  ) async {
    final zoomController = ReaderInteractiveViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderInteractiveViewer(
          enabled: true,
          resetToken: 0,
          controller: zoomController,
          contentAspectRatio: 2,
          onInteractionLockChanged: (_) {},
          child: const ColoredBox(color: Colors.red),
        ),
      ),
    );

    zoomController.toggleZoomAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(InteractiveViewer),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.entry(1, 3), closeTo(-400, 0.01));
  });

  testWidgets('a fast fling remains constrained throughout its momentum', (
    tester,
  ) async {
    final zoomController = ReaderInteractiveViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderInteractiveViewer(
          enabled: true,
          resetToken: 0,
          controller: zoomController,
          contentAspectRatio: 2,
          onInteractionLockChanged: (_) {},
          child: const ColoredBox(color: Colors.red),
        ),
      ),
    );

    zoomController.toggleZoomAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(InteractiveViewer),
      const Offset(0, -300),
      5000,
    );

    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      expect(controller.value.entry(1, 3), inInclusiveRange(-400, -200));
    }
  });

  for (final direction in [
    AxisDirection.right,
    AxisDirection.left,
    AxisDirection.down
  ]) {
    testWidgets('a second swipe catches a settling zoomed page: $direction',
        (tester) async {
      final pager = PageController();
      addTearDown(pager.dispose);
      await _pumpZoomedPager(tester, pager, direction: direction);
      final horizontal = direction != AxisDirection.down;
      final sign = direction == AxisDirection.left ? 1.0 : -1.0;
      Offset movement(double distance) =>
          horizontal ? Offset(distance * sign, 0) : Offset(0, distance * sign);
      await tester.fling(find.byType(PageView), movement(200), 1800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(pager.position.isScrollingNotifier.value, isTrue);
      expect(pager.page, greaterThan(0.5));
      final before = pager.position.pixels;
      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 16));
      expect(pager.position.pixels, closeTo(before, 0.01),
          reason: 'new touch must stop the settling animation immediately');
      await gesture.moveBy(movement(30));
      await tester.pump(const Duration(milliseconds: 16));
      final caught = pager.position.pixels;
      await gesture.moveBy(movement(80));
      await tester.pump(const Duration(milliseconds: 16));
      expect(pager.position.pixels - caught, closeTo(80, 0.01),
          reason: 'second swipe must drag without waiting for animation end');
      await gesture.moveBy(movement(pager.position.viewportDimension * .8));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pager.page, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('zoomed edge drag follows the finger and settles: $direction',
        (tester) async {
      final pager = PageController();
      addTearDown(pager.dispose);
      await _pumpZoomedPager(tester, pager, direction: direction);
      final horizontal = direction != AxisDirection.down;
      final sign = direction == AxisDirection.left ? 1.0 : -1.0;
      Offset movement(double distance) =>
          horizontal ? Offset(distance * sign, 0) : Offset(0, distance * sign);
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(movement(30));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(movement(80));
      await tester.pump(const Duration(milliseconds: 16));
      final before = pager.position.pixels;
      expect(before, greaterThan(0), reason: 'must move before pointer up');
      await gesture.moveBy(movement(80));
      await tester.pump(const Duration(milliseconds: 16));
      expect(pager.position.pixels - before, closeTo(80, 0.01),
          reason: 'pager delta must not be multiplied by image zoom');
      await gesture.moveBy(movement(280));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pager.page, 1);
      pager.jumpToPage(0);
      await tester.pumpAndSettle();
      final image = tester.widget<InteractiveViewer>(find.descendant(
        of: find.byKey(const ValueKey('zoomed-page-0')),
        matching: find.byType(InteractiveViewer),
      ));
      expect(image.transformationController!.value.getMaxScaleOnAxis(), 2);
    });
  }

  testWidgets('zoomed edge drag can reverse and settle back on its page',
      (tester) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    await _pumpZoomedPager(tester, pager);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-240, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(pager.position.pixels, greaterThan(0));
    await gesture.moveBy(const Offset(240, 0));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pager.page, 0);
  });

  testWidgets('tapping or cancelling a caught animation does not freeze paging',
      (tester) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    await _pumpZoomedPager(tester, pager);
    for (final cancel in [false, true]) {
      pager.jumpToPage(0);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final gesture = await tester.startGesture(const Offset(400, 300));
      if (cancel) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      await tester.pumpAndSettle();
      expect(pager.page, 1);
      expect(pager.position.isScrollingNotifier.value, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a caught animation cancels paging when a second finger touches',
      (tester) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    await _pumpZoomedPager(tester, pager);
    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final first = await tester.startGesture(const Offset(400, 300), pointer: 1);
    await first.moveBy(const Offset(-30, 0));
    await first.moveBy(const Offset(-40, 0));
    final second =
        await tester.startGesture(const Offset(600, 300), pointer: 2);
    await second.up();
    await tester.pumpAndSettle();
    final settled = pager.page;
    await first.moveBy(const Offset(-1000, 0));
    await first.up();
    await tester.pumpAndSettle();
    expect(pager.page, settled,
        reason: 'lifting one finger must not resume the cancelled page drag');
    pager.jumpToPage(0);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final next = await tester.startGesture(const Offset(400, 300));
    await next.moveBy(const Offset(-30, 0));
    final before = pager.position.pixels;
    await next.moveBy(const Offset(-80, 0));
    expect(pager.position.pixels - before, closeTo(80, .01),
        reason: 'a new gesture must work after cancelling a multi-touch drag');
    await next.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled edge drag settles without starting another page turn',
      (tester) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    await _pumpZoomedPager(tester, pager);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(pager.position.pixels, greaterThan(0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(pager.page, 0);
  });

  testWidgets('short fast edge fling uses release velocity to turn a page',
      (tester) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    await _pumpZoomedPager(tester, pager);
    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1800);
    await tester.pumpAndSettle();
    expect(pager.page, 1);
  });

  testWidgets('one oversized edge gesture cannot skip multiple pages',
      (tester) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    await _pumpZoomedPager(tester, pager);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-2400, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pager.page, 1);
  });

  testWidgets('a second finger cancels edge paging for the rest of the gesture',
      (tester) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    await _pumpZoomedPager(tester, pager);
    final first = await tester.startGesture(const Offset(400, 300), pointer: 1);
    await first.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(pager.position.pixels, greaterThan(0));
    final second =
        await tester.startGesture(const Offset(350, 320), pointer: 2);
    await tester.pumpAndSettle();
    await second.up();
    await first.moveBy(const Offset(-250, 0));
    await first.up();
    await tester.pumpAndSettle();
    expect(pager.page, 0);
  });

  testWidgets('a recreated page restores its saved zoom transform', (
    tester,
  ) async {
    final firstController = ReaderInteractiveViewerController();
    Matrix4? savedTransform;
    var generation = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ReaderInteractiveViewer(
              key: ValueKey(generation),
              enabled: true,
              resetToken: 0,
              controller: generation == 0 ? firstController : null,
              initialTransform: savedTransform,
              onTransformChanged: (transform) {
                savedTransform = Matrix4.copy(transform);
              },
              onInteractionLockChanged: (_) {},
              child: const ColoredBox(color: Colors.red),
            );
          },
        ),
      ),
    );

    firstController.toggleZoomAt(const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(savedTransform!.getMaxScaleOnAxis(), 2);

    rebuild(() => generation++);
    await tester.pump();
    await tester.pump();

    final restoredController = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(restoredController.value.getMaxScaleOnAxis(), 2);
  });
}

Future<void> _pumpZoomedPager(
  WidgetTester tester,
  PageController pager, {
  AxisDirection direction = AxisDirection.right,
}) async {
  final horizontal = direction != AxisDirection.down;
  final transform = Matrix4.identity();
  transform[0] = transform[5] = 2;
  transform[12] = direction == AxisDirection.left ? 0 : -800;
  transform[13] = horizontal ? -300 : -600;
  await tester.pumpWidget(MaterialApp(
      home: ReaderPageGestureHandler(
    controller: pager,
    scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
    child: PageView.builder(
      controller: pager,
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      reverse: direction == AxisDirection.left,
      allowImplicitScrolling: true,
      physics: const NeverScrollableScrollPhysics(
        parent: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      ),
      itemCount: 4,
      itemBuilder: (context, index) => ReaderInteractiveViewer(
        key: ValueKey('zoomed-page-$index'),
        enabled: true,
        resetToken: index,
        initialTransform: index == 0 ? transform : null,
        contentAspectRatio: horizontal ? 2 : null,
        pageController: pager,
        onInteractionLockChanged: (_) {},
        child: ColoredBox(color: index.isEven ? Colors.red : Colors.blue),
      ),
    ),
  )));
  await tester.pumpAndSettle();
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
