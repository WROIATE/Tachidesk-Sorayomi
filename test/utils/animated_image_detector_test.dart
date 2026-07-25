import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/utils/animated_image_detector.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'animated_image_detector_test',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('routes GIF images to the dedicated animation decoder', () async {
    final gif = await _writeFile(
      temporaryDirectory,
      'image.gif',
      [..._gifHeader, ..._gifFrame, 0x3b],
    );

    expect(await AnimatedImageDetector.isAnimated(gif), isTrue);
  });

  test('detects the animation flag in an extended WebP header', () async {
    final staticWebP = await _writeFile(
      temporaryDirectory,
      'static.webp',
      _webPHeader(animationFlag: 0),
    );
    final animatedWebP = await _writeFile(
      temporaryDirectory,
      'animated.webp',
      _webPHeader(animationFlag: 0x02),
    );

    expect(await AnimatedImageDetector.isAnimated(staticWebP), isFalse);
    expect(await AnimatedImageDetector.isAnimated(animatedWebP), isTrue);
  });

  test('leaves APNG on the Flutter fallback path', () async {
    final apng = await _writeFile(
      temporaryDirectory,
      'animated.png',
      [
        ..._pngSignature,
        ..._pngChunk(
          'IHDR',
          data: const [0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0],
        ),
        ..._pngChunk(
          'acTL',
          data: const [0, 0, 0, 2, 0, 0, 0, 0],
        ),
        ..._pngChunk('IDAT'),
      ],
    );

    expect(await AnimatedImageDetector.isAnimated(apng), isFalse);
  });

  test('ignores static image formats', () async {
    final jpeg = await _writeFile(
      temporaryDirectory,
      'static.jpg',
      const [0xff, 0xd8, 0xff, 0xd9],
    );

    expect(await AnimatedImageDetector.isAnimated(jpeg), isFalse);
  });

  test('returns false when the cached file no longer exists', () async {
    final missingFile = File('${temporaryDirectory.path}/missing.gif');

    expect(await AnimatedImageDetector.isAnimated(missingFile), isFalse);
  });
}

Future<File> _writeFile(
  Directory directory,
  String name,
  List<int> bytes,
) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(bytes);
  return file;
}

const _gifHeader = [
  71,
  73,
  70,
  56,
  57,
  97,
  1,
  0,
  1,
  0,
  0,
  0,
  0,
];

const _gifFrame = [
  0x2c,
  0,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  0,
  2,
  2,
  0x44,
  0x01,
  0,
];

const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

List<int> _webPHeader({required int animationFlag}) => [
      82,
      73,
      70,
      70,
      14,
      0,
      0,
      0,
      87,
      69,
      66,
      80,
      86,
      80,
      56,
      88,
      10,
      0,
      0,
      0,
      animationFlag,
    ];

List<int> _pngChunk(String type, {List<int> data = const []}) => [
      data.length >> 24 & 0xff,
      data.length >> 16 & 0xff,
      data.length >> 8 & 0xff,
      data.length & 0xff,
      ...type.codeUnits,
      ...data,
      0,
      0,
      0,
      0,
    ];
