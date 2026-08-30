// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'animated_image_detector.dart';

typedef LoadedImageFile = ({String path, bool isAnimated});

Future<LoadedImageFile?> loadImageFile({
  required CacheManager cacheManager,
  required String url,
  Map<String, String>? headers,
}) async {
  final file = await cacheManager.getSingleFile(url, headers: headers);
  return (
    path: file.path,
    isAnimated: await AnimatedImageDetector.isAnimated(file),
  );
}
