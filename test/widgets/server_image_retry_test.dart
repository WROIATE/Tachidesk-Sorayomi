import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/db_keys.dart';
import 'package:tachidesk_sorayomi/src/constants/endpoints.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/widgets/server_image.dart';

void main() {
  test('failed server image retries once after refresh settles', () async {
    final refresh = Completer<void>();
    final coordinator = ServerImageRetryCoordinator();
    var retries = 0;

    final firstAttempt = coordinator.retryAfter(
      barrier: refresh.future,
      retry: () => retries++,
    );
    final duplicateAttempt = coordinator.retryAfter(
      barrier: refresh.future,
      retry: () => retries++,
    );

    await duplicateAttempt;
    expect(coordinator.hasRetried, isTrue);
    expect(retries, 0);

    refresh.complete();
    await firstAttempt;
    expect(retries, 1);

    await coordinator.retryAfter(
      barrier: Future<void>.value(),
      retry: () => retries++,
    );
    expect(retries, 1);
  });

  test('failed refresh still releases the single image retry', () async {
    final coordinator = ServerImageRetryCoordinator();
    var retries = 0;

    await coordinator.retryAfter(
      barrier: Future<void>.error(StateError('refresh failed')),
      retry: () => retries++,
    );

    expect(retries, 1);
  });

  testWidgets('reader image evicts only its decoded memory entry on dispose', (
    tester,
  ) async {
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    final cacheDirectory = Directory.systemTemp.createTempSync(
      'sorayomi-image-cache-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => cacheDirectory.path,
        );
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      cacheDirectory.deleteSync(recursive: true);
    });

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final imageUrl = '${Endpoints.baseApi(
      baseUrl: DBKeys.serverUrl.initial,
      port: DBKeys.serverPort.initial,
      addPort: DBKeys.serverPortToggle.initial,
      appendApiToUrl: false,
    )}/page';
    final imageKey = CachedNetworkImageProvider(imageUrl);
    final image = (await tester.runAsync(_createTestImage))!;
    final imageCompleter = OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image)),
    );
    final cachedCompleter = PaintingBinding.instance.imageCache.putIfAbsent(
      imageKey,
      () => imageCompleter,
    )!;
    final loaded = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener((_, __) {
      if (!loaded.isCompleted) loaded.complete();
    });
    cachedCompleter.addListener(listener);
    await tester.pump();
    expect(loaded.isCompleted, isTrue);
    cachedCompleter.removeListener(listener);
    expect(PaintingBinding.instance.imageCache.containsKey(imageKey), isTrue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: ServerImage(
            imageUrl: '/page',
            evictFromMemoryOnDispose: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl,
      imageUrl,
    );

    await tester.pumpWidget(const SizedBox.shrink());

    expect(PaintingBinding.instance.imageCache.containsKey(imageKey), isFalse);
  });
}

Future<ui.Image> _createTestImage() {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList(const [0, 0, 0, 255]),
    1,
    1,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
