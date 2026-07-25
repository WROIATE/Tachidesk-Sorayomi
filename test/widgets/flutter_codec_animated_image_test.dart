import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/widgets/flutter_codec_animated_image.dart';

void main() {
  late Directory temporaryDirectory;
  late File animatedGif;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'flutter_codec_animated_image_test',
    );
    animatedGif = File('${temporaryDirectory.path}/animated.gif');
    await animatedGif.writeAsBytes(base64Decode(_fourFrameGifBase64));
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  testWidgets('advances frames while active and keeps an image when paused', (
    tester,
  ) async {
    Widget subject({required bool active}) => MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: FlutterCodecAnimatedImage(
              filePath: animatedGif.path,
              fit: BoxFit.contain,
              active: active,
              targetWidth: 100,
              errorBuilder: (_) => const Text('decode error'),
            ),
          ),
        );

    await tester.pumpWidget(subject(active: true));
    final decodedImage = find.byKey(
      const ValueKey('flutter-codec-animated-image-frame'),
    );
    for (var attempt = 0;
        attempt < 20 && decodedImage.evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(decodedImage, findsOneWidget);
    expect(find.text('decode error'), findsNothing);
    final firstFrame = tester.widget<RawImage>(decodedImage).image;

    Object? nextFrame = firstFrame;
    for (var attempt = 0;
        attempt < 20 && identical(nextFrame, firstFrame);
        attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      nextFrame = tester.widget<RawImage>(decodedImage).image;
    }

    expect(nextFrame, isNot(same(firstFrame)));

    await tester.pumpWidget(subject(active: false));
    await tester.pump(const Duration(milliseconds: 120));

    expect(decodedImage, findsOneWidget);
    expect(find.text('decode error'), findsNothing);
    final pausedFrame = tester.widget<RawImage>(decodedImage).image;
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<RawImage>(decodedImage).image, same(pausedFrame));

    await tester.pumpWidget(subject(active: true));
    Object? resumedFrame = pausedFrame;
    for (var attempt = 0;
        attempt < 20 && identical(resumedFrame, pausedFrame);
        attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      resumedFrame = tester.widget<RawImage>(decodedImage).image;
    }

    expect(resumedFrame, isNot(same(pausedFrame)));
  });
}

const _fourFrameGifBase64 =
    'R0lGODlhMgAyAPIAAPn+++fn59LU1fX19fn5+f///////wAAACH/C05FVFNDQVBFMi4wAwEAAAAh/wtYTVAgRGF0YVhNUDw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDkuMC1jMDAwIDc5LjE3MWMyN2ZhYiwgMjAyMi8wOC8xNi0yMjozNTo0MSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vc3R5cGUvUmVzb3VyY2VSZWYjIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCAyNC4wIChNYWNpbnRvc2gpIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOjJBMDA2MjAzQjU1MTExRUQ5QzNBOUVENDZBMEIwQzU1IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOjJBMDA2MjA0QjU1MTExRUQ5QzNBOUVENDZBMEIwQzU1Ij4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MkEwMDYyMDFCNTUxMTFFRDlDM0E5RUQ1NkEwQTBDNTUiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6MkEwMDYyMDJCNTUxMTFFRDlDM0E5RUQ1NkEwQTBDNTUiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz4B//79/Pv6+fj39vX08/Lx8O/u7ezr6uno5+bl5OPi4eDf3t3c29rZ2NfW1dTT0tHQz87NzMvKycfGxcTDwsHAv769vLu6ubi3trW0s7KxsK+urayrqqmop6alpKOioaCfnp2cm5qZmJeWlZSTkpGQj46NjIuKiYiHhoWEg4KBgH9+fXx7enl4d3Z1dHNycXBvbm1sa2ppaGdmZWRjYmFgX15dXFtaWVhXVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj08Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQQDAgEAACH5BAkIAAYALAAAAAAyADIAAAN7aLrcXTBKR6ulMmt4u93g5o1GaIpkda5Z+rDw5MZ0lNZ4MeZ5x/OXX08lHL6KxgUSyFj+mk5j9FmaDq1XbK2q7Xq/4LB4TC6bz+htWra2cdeKNicOV9btZ0caY/6Qg3+AYTtgN14ub1OIeEuLRz8AOo56VJNENJYkK44JACH5BAUIAAYALAAAAAAyADIAAAPsaLrcXTBKR6ulMmt4u93g5o1GGBFoqqJAQX4m1Mbcy9DRjLv2Lvu1EbCg8wmHReNl+GPyKs6kEhPVAKQih7MpuWI12q3Ui3tsC4Sk9xoj3M5pMnEtkxPTizMkvu7P7QBpPHpofYaHcyiDenyHjl4sCoSNj46RhIWVlSxfQJSafZyYn6CQcaOllqeTqYeirK2hq4yxsmywtVevermOmL8uwHqSwlvExUzHyEB5y1Mlzjtm0SZavddkFCvb3N3e3Bbf4uPg4eTn4x3o6+Xq7O8v7+s2BvLk9Av23fgN+ikDbvg58CfwAryCI9LhSwAAIfkECQgABgAsAwABAC8AMQAAA8Foutz+MMpJDaj4gTHJzSBAgCQllih0puyytuwLo/JM1pZd1SIx6hGe7wfUEBW9owq28bmGzgiBExtALdBRMjpS3qzZ7JZr8IbA4XRYYcY01fChwVqN2+ftHdqexucnb3x9YCmBgll+hXuHcoQ0i4wjjiWGkZJRlJCMiY+WUAOTN55qRaWmp6ipqqusra4Vo7GIC6C1tre4ubq5Dru+v74PwMPEVL3FyLgSyczGEc3FGNDAJNO8KNagczDWQMyo1CUJACH5BAUIAAYALAAAAAAyADIAAAP3aLrc/jDKaYq9OBfKnf4g0FHgBQxEqq6pOD6lScTYy9AyXr+6Bcw9yyhY+BGFJKLxuJEwl0znEWrSRZhFoCyFg2GpWW63gc1mfuKY6/ZFadGqGGFAbq/CcbhYVX+6WSt6e1xsfoCHiHwLZSeJjioohVN/j4iRi3aViW6YhpqWKZ2Tn6AEokqUpJChCoypqnOsFZmwq6attLWxt7OeugOcuFi6h6dlx029yMeSy1jNzkfQ0UHT1GPG19jC2lYNxOCKDcDk5ebn6OnoEert7u0S7/LzdPH09+cc+Pv1+vzzNv69s7FA4DqCDAyWQ/jAIEN79x52GEgwAQA7';
