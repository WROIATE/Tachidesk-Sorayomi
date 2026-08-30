// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/material.dart';

class EvictingFileImage extends StatefulWidget {
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
  State<EvictingFileImage> createState() => _EvictingFileImageState();
}

class _EvictingFileImageState extends State<EvictingFileImage> {
  late FileImage _provider;

  @override
  void initState() {
    super.initState();
    _provider = FileImage(File(widget.filePath));
  }

  @override
  void didUpdateWidget(covariant EvictingFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath == widget.filePath) return;

    _evictAfterFrame(_provider, oldWidget.evictFromMemoryOnDispose);
    _provider = FileImage(File(widget.filePath));
  }

  void _evictAfterFrame(FileImage provider, bool enabled) {
    if (!enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaintingBinding.instance.imageCache.evict(
        provider,
        includeLive: false,
      );
    });
  }

  @override
  void dispose() {
    _evictAfterFrame(_provider, widget.evictFromMemoryOnDispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
        image: _provider,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, _, __) => widget.errorBuilder(context),
      );
}
