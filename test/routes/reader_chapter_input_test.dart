import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_interactive_viewer.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_page_gesture_handler.dart';
import 'package:tachidesk_sorayomi/src/routes/reader_cupertino_page.dart';

void main() {
  for (final reverse in [false, true]) {
    testWidgets('chapter entry accepts an immediate edge fling: $reverse',
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

      Route<void> chapter(PageController controller, {Offset? entryOffset}) =>
          ReaderCupertinoPage(
            chapterEntryOffset: entryOffset,
            child: _Pages(controller: controller, reverse: reverse),
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
        Offset(reverse ? 150 : 650, 300),
        Offset(reverse ? 180 : -180, 0),
        1800,
      );
      await tester.pumpAndSettle();

      expect(next.page, 1);
    });
  }
}

class _Pages extends StatelessWidget {
  const _Pages({required this.controller, required this.reverse});

  final PageController controller;
  final bool reverse;

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
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      );
}
