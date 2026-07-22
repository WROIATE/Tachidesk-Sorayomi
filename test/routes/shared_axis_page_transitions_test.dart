import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/routes/shared_axis_page_transitions.dart';

void main() {
  const builder = SharedAxisXPageTransitionsBuilder();

  test('uses Mihon shared axis duration', () {
    expect(builder.transitionDuration, const Duration(milliseconds: 300));
    expect(
        builder.reverseTransitionDuration, const Duration(milliseconds: 300));
  });

  testWidgets('moves both pages along the horizontal axis', (tester) async {
    final primary = AnimationController(vsync: tester);
    final secondary = AnimationController(vsync: tester);
    const childKey = ValueKey('page');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => builder.buildTransitions<void>(
            MaterialPageRoute(builder: (_) => const SizedBox()),
            context,
            primary,
            secondary,
            const SizedBox(key: childKey),
          ),
        ),
      ),
    );

    expect(_translationXs(tester, childKey), contains(closeTo(30.0, 0.001)));
    expect(_opacities(tester, childKey), contains(closeTo(0.0, 0.001)));

    primary.value = 1.0;
    await tester.pump();
    expect(_translationXs(tester, childKey), everyElement(closeTo(0.0, 0.001)));
    expect(_opacities(tester, childKey), everyElement(closeTo(1.0, 0.001)));

    secondary.value = 1.0;
    await tester.pump();
    expect(_translationXs(tester, childKey), contains(closeTo(-30.0, 0.001)));
    expect(_opacities(tester, childKey), contains(closeTo(0.0, 0.001)));

    primary.dispose();
    secondary.dispose();
  });

  testWidgets('matches Mihon reader push and pop movement', (tester) async {
    final push = AnimationController(vsync: tester);
    final pop = AnimationController(vsync: tester);
    const pushKey = ValueKey('push');
    const popKey = ValueKey('pop');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            SharedAxisXPushEnterTransition(
              animation: push,
              child: const SizedBox(key: pushKey),
            ),
            SharedAxisXPopExitTransition(
              animation: pop,
              child: const SizedBox(key: popKey),
            ),
          ],
        ),
      ),
    );

    expect(_translationXs(tester, pushKey), everyElement(closeTo(30, 0.001)));
    expect(_opacities(tester, pushKey), everyElement(closeTo(0, 0.001)));
    expect(_translationXs(tester, popKey), everyElement(closeTo(0, 0.001)));
    expect(_opacities(tester, popKey), everyElement(closeTo(1, 0.001)));

    push.value = 0.35;
    pop.value = 0.35;
    await tester.pump();

    expect(_opacities(tester, popKey), everyElement(greaterThan(0)));

    push.value = 195 / 300;
    pop.value = 195 / 300;
    await tester.pump();

    expect(_opacities(tester, pushKey), everyElement(closeTo(1, 0.001)));
    expect(_opacities(tester, popKey), everyElement(closeTo(0, 0.001)));

    push.value = 1;
    pop.value = 1;
    await tester.pump();

    expect(_translationXs(tester, pushKey), everyElement(closeTo(0, 0.001)));
    expect(_opacities(tester, pushKey), everyElement(closeTo(1, 0.001)));
    expect(_translationXs(tester, popKey), everyElement(closeTo(30, 0.001)));
    expect(_opacities(tester, popKey), everyElement(closeTo(0, 0.001)));

    push.dispose();
    pop.dispose();
  });
}

Iterable<double> _translationXs(WidgetTester tester, Key childKey) {
  return tester
      .widgetList<Transform>(
        find.ancestor(
          of: find.byKey(childKey),
          matching: find.byType(Transform),
        ),
      )
      .map((transform) => transform.transform.storage[12]);
}

Iterable<double> _opacities(WidgetTester tester, Key childKey) {
  return tester
      .widgetList<FadeTransition>(
        find.ancestor(
          of: find.byKey(childKey),
          matching: find.byType(FadeTransition),
        ),
      )
      .map((transition) => transition.opacity.value);
}
