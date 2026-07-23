// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

import '../../../../../constants/app_constants.dart';

class ReaderInteractiveViewerController {
  _ReaderInteractiveViewerState? _state;

  void _attach(_ReaderInteractiveViewerState state) => _state = state;

  void _detach(_ReaderInteractiveViewerState state) {
    if (identical(_state, state)) _state = null;
  }

  void toggleZoomAt(Offset globalPosition) =>
      _state?._toggleDoubleTapZoom(globalPosition);
}

class ReaderInteractiveViewer extends StatefulWidget {
  const ReaderInteractiveViewer({
    super.key,
    required this.enabled,
    required this.resetToken,
    required this.onInteractionLockChanged,
    required this.child,
    this.controller,
  });

  final bool enabled;
  final Object resetToken;
  final ValueChanged<bool> onInteractionLockChanged;
  final Widget child;
  final ReaderInteractiveViewerController? controller;

  @override
  State<ReaderInteractiveViewer> createState() =>
      _ReaderInteractiveViewerState();
}

class _ReaderInteractiveViewerState extends State<ReaderInteractiveViewer>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 1;
  static const double _doubleTapScale = 2;
  static const double _maxScale = 5;
  static const double _zoomTolerance = 0.001;

  final TransformationController _controller = TransformationController();
  final Map<int, Offset> _pointerPositions = <int, Offset>{};

  late final AnimationController _doubleTapAnimationController;
  Animation<Matrix4>? _doubleTapAnimation;
  Matrix4? _pinchStartMatrix;
  Offset? _pinchSceneFocalPoint;
  double? _pinchStartDistance;
  Size _viewportSize = Size.zero;
  bool _hasMultiplePointers = false;
  bool _isZoomed = false;
  bool _isInteractionLocked = false;

  @override
  void initState() {
    super.initState();
    _doubleTapAnimationController = AnimationController(
      vsync: this,
      duration: kDuration,
    )..addListener(_updateDoubleTapAnimation);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant ReaderInteractiveViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if ((oldWidget.enabled && !widget.enabled) ||
        oldWidget.resetToken != widget.resetToken) {
      _resetInteraction();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _doubleTapAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _resetInteraction() {
    final wasInteractionLocked = _isInteractionLocked;
    _doubleTapAnimationController.stop();
    _controller.value = Matrix4.identity();
    _pointerPositions.clear();
    _clearPinchStart();
    _hasMultiplePointers = false;
    _isZoomed = false;
    _isInteractionLocked = false;

    if (wasInteractionLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInteractionLockChanged(false);
      });
    }
  }

  void _beginPinch() {
    _doubleTapAnimationController.stop();
    final points = _pointerPositions.values.take(2).toList();
    if (points.length < 2) return;

    final distance = (points.first - points.last).distance;
    if (distance <= _zoomTolerance) {
      _clearPinchStart();
      return;
    }

    final focalPoint = (points.first + points.last) / 2;
    _pinchStartMatrix = Matrix4.copy(_controller.value);
    _pinchSceneFocalPoint = _controller.toScene(focalPoint);
    _pinchStartDistance = distance;
  }

  void _updatePinch(PointerMoveEvent event, Size viewportSize) {
    _pointerPositions[event.pointer] = event.localPosition;
    if (_pointerPositions.length < 2) return;

    if (_pinchStartMatrix == null ||
        _pinchSceneFocalPoint == null ||
        _pinchStartDistance == null) {
      _beginPinch();
      return;
    }

    final points = _pointerPositions.values.take(2).toList();
    final focalPoint = (points.first + points.last) / 2;
    final distance = (points.first - points.last).distance;
    final startScale = _pinchStartMatrix!.getMaxScaleOnAxis();
    final scale = (startScale * distance / _pinchStartDistance!)
        .clamp(_minScale, _maxScale)
        .toDouble();

    var translationX = focalPoint.dx - _pinchSceneFocalPoint!.dx * scale;
    var translationY = focalPoint.dy - _pinchSceneFocalPoint!.dy * scale;
    translationX =
        translationX.clamp(viewportSize.width * (1 - scale), 0.0).toDouble();
    translationY =
        translationY.clamp(viewportSize.height * (1 - scale), 0.0).toDouble();

    final matrix = Matrix4.identity();
    matrix[0] = scale;
    matrix[5] = scale;
    matrix[12] = translationX;
    matrix[13] = translationY;
    _controller.value = matrix;
    _refreshInteractionState();
  }

  void _endPointer(PointerEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length >= 2) {
      _beginPinch();
    } else {
      _clearPinchStart();
    }
    _refreshInteractionState();
  }

  void _clearPinchStart() {
    _pinchStartMatrix = null;
    _pinchSceneFocalPoint = null;
    _pinchStartDistance = null;
  }

  void _toggleDoubleTapZoom(Offset globalPosition) {
    if (!mounted || !widget.enabled || _viewportSize.isEmpty) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final localPosition = renderObject.globalToLocal(globalPosition);
    final focalPoint = Offset(
      localPosition.dx.clamp(0.0, _viewportSize.width).toDouble(),
      localPosition.dy.clamp(0.0, _viewportSize.height).toDouble(),
    );
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final target = currentScale > _minScale + _zoomTolerance
        ? Matrix4.identity()
        : _matrixForScaleAt(focalPoint, _doubleTapScale);

    _doubleTapAnimation = Matrix4Tween(
      begin: Matrix4.copy(_controller.value),
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _doubleTapAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _doubleTapAnimationController.forward(from: 0);
  }

  Matrix4 _matrixForScaleAt(Offset focalPoint, double scale) {
    final sceneFocalPoint = _controller.toScene(focalPoint);
    final translationX = (focalPoint.dx - sceneFocalPoint.dx * scale)
        .clamp(_viewportSize.width * (1 - scale), 0.0)
        .toDouble();
    final translationY = (focalPoint.dy - sceneFocalPoint.dy * scale)
        .clamp(_viewportSize.height * (1 - scale), 0.0)
        .toDouble();
    final matrix = Matrix4.identity();
    matrix[0] = scale;
    matrix[5] = scale;
    matrix[12] = translationX;
    matrix[13] = translationY;
    return matrix;
  }

  void _updateDoubleTapAnimation() {
    final animation = _doubleTapAnimation;
    if (animation == null) return;
    _controller.value = animation.value;
    _refreshInteractionState();
  }

  void _refreshInteractionState() {
    final hasMultiplePointers = _pointerPositions.length > 1;
    final isZoomed =
        _controller.value.getMaxScaleOnAxis() > _minScale + _zoomTolerance;
    final isInteractionLocked = hasMultiplePointers || isZoomed;

    if (mounted &&
        (hasMultiplePointers != _hasMultiplePointers ||
            isZoomed != _isZoomed)) {
      setState(() {
        _hasMultiplePointers = hasMultiplePointers;
        _isZoomed = isZoomed;
      });
    } else {
      _hasMultiplePointers = hasMultiplePointers;
      _isZoomed = isZoomed;
    }

    if (isInteractionLocked != _isInteractionLocked) {
      _isInteractionLocked = isInteractionLocked;
      widget.onInteractionLockChanged(isInteractionLocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return Listener(
          onPointerDown: (event) {
            if (_doubleTapAnimationController.isAnimating) {
              _doubleTapAnimationController.stop();
            }
            _pointerPositions[event.pointer] = event.localPosition;
            if (_pointerPositions.length == 2) _beginPinch();
            _refreshInteractionState();
          },
          onPointerMove: (event) => _updatePinch(event, constraints.biggest),
          onPointerUp: _endPointer,
          onPointerCancel: _endPointer,
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: _minScale,
            maxScale: _maxScale,
            scaleEnabled: false,
            panEnabled: _isZoomed && !_hasMultiplePointers,
            onInteractionUpdate: (_) => _refreshInteractionState(),
            child: widget.child,
          ),
        );
      },
    );
  }
}
