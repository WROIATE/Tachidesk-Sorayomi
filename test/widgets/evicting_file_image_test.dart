import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/widgets/evicting_file_image.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'evicting_file_image_test-',
    );
    file = File('${directory.path}/static.png');
    await file.writeAsBytes(base64Decode(_staticPngBase64));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  testWidgets('keeps source dimensions and evicts its decoded image', (
    tester,
  ) async {
    final provider = FileImage(file);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: EvictingFileImage(
            filePath: file.path,
            fit: BoxFit.contain,
            evictFromMemoryOnDispose: true,
            errorBuilder: (_) => const Text('decode error'),
          ),
        ),
      ),
    );

    final rawImage = find.byType(RawImage);
    ui.Image? image;
    for (var attempt = 0; attempt < 20 && image == null; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
      image = tester.widget<RawImage>(rawImage).image;
    }

    expect(find.text('decode error'), findsNothing);
    expect(rawImage, findsOneWidget);
    expect(image, isNotNull);
    expect(image!.width, 16);
    expect(image.height, 16);
    expect(PaintingBinding.instance.imageCache.containsKey(provider), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(PaintingBinding.instance.imageCache.containsKey(provider), isFalse);
  });
}

const _staticPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAACkVBMVEUAAABgyfhgyfhfyfhfyfheyPhdyPhdyPhbyPhbx/hbx/hbx/hhyflhyflgyfhfyfhfyfheyPhdyPhdyPhcyPhbyPhbyPhax/hhyflhyflgyfhgyfhgyfhfyfheyPhdyPhdyPhcyPhcyPhbyPhbx/hhyflhyflhyflgyfhfyfhfyfheyPhdyPhdyPhcyPhcyPhbyPhgyfhhyflhyflhyflhyflgyfhfyfhfyfheyPhdyPhdyPhdyPhcyPhfyfhgyfhgyfhhyflhyflgyfhfyfhfyfheyPheyPheyPhhyfhax/hZx/hZx/hZx/hgyfhgyfhgyfhgyfhgyfhfyfhfyfheyPheyPhdyPhayPhaxvhYx/hax/hZx/hZx/hfyfhfyfhfyfhfyfhfyfhfyfheyPheyPhdyPhcyPhbyPhbx/hax/hZx/hZx/hZx/hfyfhfyfhfyfhfyfheyPheyPhgyfhgyfhcyPhcyPhbyPhax/hZx/hZx/hVx/pZx/heyPheyPheyPhdyPhdyPhhyfgntfU/vvdXxvhbyPhbx/hax/hZx/hZx/hZx/hZx/hfyfheyPheyPhdyPhfyfgtt/YzufYyufY+vfdWxvhbyPlZx/hax/hZx/hZx/hdyPhdyPhZx/gAdu4yufYyufYxufYxuvc4s+5DrOIwk8158v9XxfYyufYwufYxufYxufYxuvcsrOoTc7UHWpwGWpwGWp0FWp0EWZwyufYyufYxuPYxu/krqukVcLMIWJsHWp0GWp0FWp0EWZwDWJwCWJsxufYwufYSbrASb7EHWp0GWp0FWp0FWp0EWZwDWJwDWJwBV5svuPYnrusVdbgGWp0FWp0FWp0EWZwDWJwCWJsBWJsCWJv///8gWJ40AAAA2nRSTlMAAAAAQ9/29figDgAAAAA61v///7YeAAAAAAA72P///7UcAAAAAAA72P///7UcAAAAAAAAO9j///+1HAAAAAAAADvY////tRwAAAAAAAAAADvY////tRsAAAAAAAEAADTZ////tRoUgpmYm3gPAAA12f//tRoTqf///+RKAAAAADvYthoTqf///99FAAAAAAAALBoVqf///95FAAAAAAAAAI7////4XAAAAAAAPtj///+yHAAAAAAAADvY////tBwAAAAAAAA71v///7UeAAAAAABE3/f2+KAOADhSMAsAAAABYktHRNruAyaCAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wkFCDILEnuNjgAAAQZJREFUGNNjYAABRiZmFlY2dg5OLm4wn4eXj19AUEhYRFRMHMSXkJSSlpGVk1dQVFJWAfFV1dQ1NLW0dXT19A2AfEMjYxNTM3MLSytrG1sg387ewdHJ2cXVzd3D08vbx5fBzz8gMCg4JDQsPCIyKjomliEuPiExKTklNS09IzMrOyeXIS+/oLCouKS0rLyisqq6ppahrr6hsam5pbWtvaOzq7unl6Gvf8LESZOnTJ02fcbMWbPnAK2ZO2/+goWLFi9Zumz5ipVghzOsWr1m7br1GzZu2rxlK1hg2/YdO3ft3rN33/4DBw+BRQ4fOXrs+ImTp06fOXsOoun8hYuXLl+5eu36jZsApU5cftgkd/0AAAAldEVYdGRhdGU6Y3JlYXRlADIwMTktMDktMDVUMTU6NTA6MTEtMDc6MDCgLHNtAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDE5LTA5LTA1VDE1OjUwOjExLTA3OjAw0XHL0QAAAABJRU5ErkJggg==';
