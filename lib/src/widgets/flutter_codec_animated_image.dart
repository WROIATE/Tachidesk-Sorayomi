// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'custom_circular_progress_indicator.dart';

class FlutterCodecAnimatedImage extends StatefulWidget {
  const FlutterCodecAnimatedImage({
    super.key,
    required this.filePath,
    required this.fit,
    required this.active,
    required this.targetWidth,
    required this.errorBuilder,
  });

  final String filePath;
  final BoxFit fit;
  final bool active;
  final int targetWidth;
  final WidgetBuilder errorBuilder;

  @override
  State<FlutterCodecAnimatedImage> createState() =>
      _FlutterCodecAnimatedImageState();
}

class _FlutterCodecAnimatedImageState extends State<FlutterCodecAnimatedImage>
    with SingleTickerProviderStateMixin {
  static const _minimumFrameDuration = Duration(milliseconds: 10);

  late final Ticker _ticker;
  ui.Codec? _codec;
  ui.FrameInfo? _pendingFrame;
  ui.Image? _image;
  Duration _elapsed = Duration.zero;
  Duration _frameDeadline = Duration.zero;
  int _framesEmitted = 0;
  int _generation = 0;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_handleTick);
    _startDecode();
  }

  @override
  void didUpdateWidget(covariant FlutterCodecAnimatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.targetWidth != widget.targetWidth) {
      _discardCurrentImage();
      _startDecode();
    } else if (oldWidget.active != widget.active) {
      if (widget.active) {
        _startDecode();
      } else {
        _stopPlayback();
        if (_image == null) _startDecode();
      }
    }
  }

  void _startDecode() {
    final generation = _stopPlayback();
    if (_image == null) {
      _loading = true;
      _hasError = false;
    }
    unawaited(_decodeFirstFrame(generation, widget.active));
  }

  Future<void> _decodeFirstFrame(int generation, bool animate) async {
    ui.Codec? codec;
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(widget.filePath);
      codec = await ui.instantiateImageCodecFromBuffer(
        buffer,
        targetWidth: widget.targetWidth,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      if (!_isCurrent(generation) || widget.active != animate) {
        frame.image.dispose();
        return;
      }

      if (!animate || codec.frameCount == 1) {
        _replaceImage(frame.image);
        return;
      }

      _codec = codec;
      codec = null;
      _framesEmitted = 1;
      _elapsed = Duration.zero;
      _frameDeadline = _frameDuration(frame.duration);
      _replaceImage(frame.image);
      _ticker.start();
      unawaited(_decodeNextFrame(generation));
    } catch (_) {
      _showError(generation);
    } finally {
      codec?.dispose();
    }
  }

  Future<void> _decodeNextFrame(int generation) async {
    final codec = _codec;
    if (codec == null) return;

    try {
      final frame = await codec.getNextFrame();
      if (!_isCurrent(generation) || codec != _codec) {
        frame.image.dispose();
        return;
      }
      _pendingFrame?.image.dispose();
      _pendingFrame = frame;
      _presentFrameIfDue(_elapsed);
    } catch (_) {
      _showError(generation);
    }
  }

  void _handleTick(Duration elapsed) {
    _elapsed = elapsed;
    _presentFrameIfDue(elapsed);
  }

  void _presentFrameIfDue(Duration elapsed) {
    final frame = _pendingFrame;
    final codec = _codec;
    if (frame == null || codec == null || elapsed < _frameDeadline) return;

    _pendingFrame = null;
    _replaceImage(frame.image);
    _framesEmitted++;
    if (!_shouldContinue(codec)) {
      _ticker.stop();
      codec.dispose();
      _codec = null;
      return;
    }

    _frameDeadline = elapsed + _frameDuration(frame.duration);
    unawaited(_decodeNextFrame(_generation));
  }

  bool _shouldContinue(ui.Codec codec) {
    if (codec.repetitionCount == -1) return true;
    final completedCycles = _framesEmitted ~/ codec.frameCount;
    return completedCycles <= codec.repetitionCount;
  }

  Duration _frameDuration(Duration duration) =>
      duration > Duration.zero ? duration : _minimumFrameDuration;

  bool _isCurrent(int generation) => mounted && generation == _generation;

  int _stopPlayback() {
    _generation++;
    _ticker.stop();
    _elapsed = Duration.zero;
    _pendingFrame?.image.dispose();
    _pendingFrame = null;
    _codec?.dispose();
    _codec = null;
    return _generation;
  }

  void _replaceImage(ui.Image image) {
    if (!mounted) {
      image.dispose();
      return;
    }
    final previousImage = _image;
    setState(() {
      _image = image;
      _loading = false;
      _hasError = false;
    });
    if (previousImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previousImage.dispose();
      });
    }
  }

  void _showError(int generation) {
    if (!_isCurrent(generation)) return;
    _stopPlayback();
    setState(() {
      _loading = false;
      _hasError = true;
    });
  }

  void _discardCurrentImage() {
    final image = _image;
    _image = null;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        image.dispose();
      });
    }
  }

  @override
  void dispose() {
    _stopPlayback();
    _image?.dispose();
    _image = null;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_image != null)
            RawImage(
              key: const ValueKey('flutter-codec-animated-image-frame'),
              image: _image,
              fit: widget.fit,
            ),
          if (_loading)
            const CenterSorayomiShimmerIndicator()
          else if (_hasError)
            widget.errorBuilder(context),
        ],
      ),
    );
  }
}
