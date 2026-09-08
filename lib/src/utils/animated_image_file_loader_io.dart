// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'animated_image_detector.dart';

typedef LoadedImageFile = ({
  String path,
  bool isAnimated,
  double? aspectRatio,
});

Future<LoadedImageFile?> loadImageFile({
  required CacheManager cacheManager,
  required String url,
  Map<String, String>? headers,
}) async {
  final file = await cacheManager.getSingleFile(url, headers: headers);
  return (
    path: file.path,
    isAnimated: await AnimatedImageDetector.isAnimated(file),
    aspectRatio: await readImageAspectRatio(file),
  );
}

@visibleForTesting
Future<double?> readImageAspectRatio(File file) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 || descriptor.height <= 0) return null;
    return descriptor.width / descriptor.height;
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
