// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

class EvictingFileImage extends StatelessWidget {
  const EvictingFileImage({
    super.key,
    required this.filePath,
    required this.fit,
    required this.evictFromMemoryOnDispose,
    required this.errorBuilder,
  });

  final String filePath;
  final BoxFit fit;
  final bool evictFromMemoryOnDispose;
  final WidgetBuilder errorBuilder;

  @override
  Widget build(BuildContext context) => errorBuilder(context);
}
