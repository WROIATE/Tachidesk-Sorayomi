import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_interactive_viewer.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_page_gesture_handler.dart';
import 'package:tachidesk_sorayomi/src/routes/reader_cupertino_page.dart';

void main() {
  testWidgets('replacement during an active page drag accepts repeated swipes',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final first = PageController(initialPage: 4);
    final next = PageController();
    addTearDown(first.dispose);
    addTearDown(next.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('Details')),
    ));
    var replaced = false;
    navigatorKey.currentState!.push(ReaderCupertinoPage(
      child: Listener(
        onPointerMove: (event) {
          if (!replaced && event.position.dx < 650) {
            replaced = true;
            navigatorKey.currentState!.pushReplacement(ReaderCupertinoPage(
              chapterEntryOffset: const Offset(1, 0),
              child: _Pages(controller: next, reverse: false),
            ).createRoute(navigatorKey.currentContext!));
          }
        },
        child: _Pages(controller: first, reverse: false),
      ),
    ).createRoute(navigatorKey.currentContext!));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(750, 300));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(replaced, isTrue);
    for (var i = 0; i < 3; i++) {
      final before = next.page!;
      await tester.flingFrom(
          const Offset(750, 300), const Offset(-180, 0), 1800);
      await tester.pump(const Duration(milliseconds: 80));
      expect(next.page, greaterThan(before),
          reason: 'Each swipe after replacement must move the page');
    }
    await tester.pumpAndSettle();
    expect(next.page, greaterThan(0));
  });

  for (final reverse in [false, true]) {
    for (final imagePage in [false, true]) {
      testWidgets(
          'chapter entry accepts an immediate edge fling: $reverse, image: $imagePage',
          (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('Details')),
        ));
        final first = PageController();
        final next = PageController();
        addTearDown(first.dispose);
        addTearDown(next.dispose);
        if (imagePage) {
          await tester.runAsync(() => precacheImage(
                const AssetImage('assets/icons/light_icon.png'),
                navigatorKey.currentContext!,
              ));
        }

        Route<void> chapter(PageController controller, {Offset? entryOffset}) =>
            ReaderCupertinoPage(
              chapterEntryOffset: entryOffset,
              child: _Pages(
                  controller: controller,
                  reverse: reverse,
                  pageChild: imagePage
                      ? Image.asset('assets/icons/light_icon.png',
                          fit: BoxFit.contain)
                      : const ColoredBox(color: Colors.blue)),
            ).createRoute(navigatorKey.currentContext!);

        navigatorKey.currentState!.push(chapter(first));
        await tester.pumpAndSettle();
        final incoming = chapter(
          next,
          entryOffset: Offset(reverse ? -1 : 1, 0),
        );
        navigatorKey.currentState!.pushReplacement(incoming);
        await tester.pump(const Duration(milliseconds: 50));
        expect(next.hasClients, isTrue);
        expect(navigatorKey.currentState!.userGestureInProgress, isFalse);
        await tester.flingFrom(
          Offset(reverse ? 40 : 760, 300),
          Offset(reverse ? 180 : -180, 0),
          1800,
        );
        await tester.pumpAndSettle();

        expect(next.page, 1);
      });
    }
  }
}

class _Pages extends StatelessWidget {
  const _Pages(
      {required this.controller,
      required this.reverse,
      this.pageChild = const ColoredBox(color: Colors.blue)});

  final PageController controller;
  final bool reverse;
  final Widget pageChild;

  @override
  Widget build(BuildContext context) => ReaderPageGestureHandler(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: PageView.builder(
          controller: controller,
          reverse: reverse,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: 5,
          itemBuilder: (_, index) => ReaderInteractiveViewer(
            key: ValueKey(index),
            enabled: true,
            resetToken: 1,
            pageController: controller,
            onInteractionLockChanged: (_) {},
            child: pageChild,
          ),
        ),
      );
}
