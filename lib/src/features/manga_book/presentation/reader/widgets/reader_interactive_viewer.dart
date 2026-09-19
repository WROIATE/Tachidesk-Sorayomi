// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../../constants/app_constants.dart';
import 'reader_page_gesture_handler.dart';

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
    this.contentAspectRatio,
    this.pageController,
    this.initialTransform,
    this.onTransformChanged,
  });

  final bool enabled;
  final Object resetToken;
  final ValueChanged<bool> onInteractionLockChanged;
  final Widget child;
  final ReaderInteractiveViewerController? controller;
  final double? contentAspectRatio;
  final PageController? pageController;
  final Matrix4? initialTransform;
  final ValueChanged<Matrix4>? onTransformChanged;

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
  static const double _edgeTolerance = 1;

  late final TransformationController _controller;
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
  bool _isConstrainingTransform = false;
  Drag? _pageDrag;
  VelocityTracker? _pageVelocity;
  Matrix4? _pageDragTransform;
  double _pageDragOrigin = 0;
  bool _panAccepted = false;
  bool _hadMultiplePointers = false;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController(
      !widget.enabled || widget.initialTransform == null
          ? Matrix4.identity()
          : Matrix4.copy(widget.initialTransform!),
    )..addListener(_handleControllerChanged);
    _doubleTapAnimationController = AnimationController(
      vsync: this,
      duration: kDuration,
    )..addListener(_updateDoubleTapAnimation);
    widget.controller?._attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleControllerChanged();
    });
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
    } else if (oldWidget.contentAspectRatio != widget.contentAspectRatio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleControllerChanged();
      });
    }
  }

  @override
  void dispose() {
    _cancelPageDrag();
    widget.controller?._detach(this);
    _doubleTapAnimationController.dispose();
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _resetInteraction() {
    _cancelPageDrag();
    _pageDragTransform = null;
    final wasInteractionLocked = _isInteractionLocked;
    _doubleTapAnimationController.stop();
    _isConstrainingTransform = true;
    _controller.value = Matrix4.identity();
    _isConstrainingTransform = false;
    widget.onTransformChanged?.call(Matrix4.identity());
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

  void _updatePinch(Size viewportSize) {
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

    final translation = _constrainTranslation(
      viewportSize: viewportSize,
      scale: scale,
      translation: Offset(
        focalPoint.dx - _pinchSceneFocalPoint!.dx * scale,
        focalPoint.dy - _pinchSceneFocalPoint!.dy * scale,
      ),
    );

    final matrix = Matrix4.identity();
    matrix[0] = scale;
    matrix[5] = scale;
    matrix[12] = translation.dx;
    matrix[13] = translation.dy;
    _controller.value = matrix;
    _refreshInteractionState();
  }

  void _updatePointer(PointerMoveEvent event, Size viewportSize) {
    _pointerPositions[event.pointer] = event.localPosition;

    if (_pointerPositions.length > 1) {
      _updatePinch(viewportSize);
      return;
    }

    _pageVelocity?.addPosition(event.timeStamp, event.position);
    _updatePageDrag(event);
  }

  void _endPointer(PointerEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length >= 2) {
      _beginPinch();
    } else {
      _clearPinchStart();
    }
    _refreshInteractionState();
    if (_pointerPositions.isEmpty) {
      _pageVelocity?.addPosition(event.timeStamp, event.position);
      _finishPageDrag(cancelled: event is PointerCancelEvent);
      _panAccepted = false;
    }
  }

  void _clearPinchStart() {
    _pinchStartMatrix = null;
    _pinchSceneFocalPoint = null;
    _pinchStartDistance = null;
  }

  void _toggleDoubleTapZoom(Offset globalPosition) {
    if (!mounted || !widget.enabled || _viewportSize.isEmpty) return;
    _cancelPageDrag();
    _pageDragTransform = null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final localPosition = renderObject.globalToLocal(globalPosition);
    if (!(Offset.zero & renderObject.size).contains(localPosition)) return;
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
    final translation = _constrainTranslation(
      viewportSize: _viewportSize,
      scale: scale,
      translation: Offset(
        focalPoint.dx - sceneFocalPoint.dx * scale,
        focalPoint.dy - sceneFocalPoint.dy * scale,
      ),
    );
    final matrix = Matrix4.identity();
    matrix[0] = scale;
    matrix[5] = scale;
    matrix[12] = translation.dx;
    matrix[13] = translation.dy;
    return matrix;
  }

  Rect _contentRect(Size viewportSize) {
    final aspectRatio = widget.contentAspectRatio;
    if (aspectRatio == null ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        viewportSize.isEmpty) {
      return Offset.zero & viewportSize;
    }

    final viewportAspectRatio = viewportSize.width / viewportSize.height;
    if (aspectRatio > viewportAspectRatio) {
      final height = viewportSize.width / aspectRatio;
      return Rect.fromLTWH(
        0,
        (viewportSize.height - height) / 2,
        viewportSize.width,
        height,
      );
    }

    final width = viewportSize.height * aspectRatio;
    return Rect.fromLTWH(
      (viewportSize.width - width) / 2,
      0,
      width,
      viewportSize.height,
    );
  }

  ({double min, double max}) _translationBounds({
    required double viewportExtent,
    required double contentStart,
    required double contentExtent,
    required double scale,
  }) {
    final scaledExtent = contentExtent * scale;
    if (scaledExtent <= viewportExtent) {
      final centeredStart = (viewportExtent - scaledExtent) / 2;
      final translation = centeredStart - contentStart * scale;
      return (min: translation, max: translation);
    }

    return (
      min: viewportExtent - (contentStart + contentExtent) * scale,
      max: -contentStart * scale,
    );
  }

  Offset _constrainTranslation({
    required Size viewportSize,
    required double scale,
    required Offset translation,
  }) {
    final contentRect = _contentRect(viewportSize);
    final horizontalBounds = _translationBounds(
      viewportExtent: viewportSize.width,
      contentStart: contentRect.left,
      contentExtent: contentRect.width,
      scale: scale,
    );
    final verticalBounds = _translationBounds(
      viewportExtent: viewportSize.height,
      contentStart: contentRect.top,
      contentExtent: contentRect.height,
      scale: scale,
    );
    return Offset(
      translation.dx
          .clamp(horizontalBounds.min, horizontalBounds.max)
          .toDouble(),
      translation.dy.clamp(verticalBounds.min, verticalBounds.max).toDouble(),
    );
  }

  void _constrainCurrentTransform() {
    if (_viewportSize.isEmpty) return;
    final matrix = _controller.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = _constrainTranslation(
      viewportSize: _viewportSize,
      scale: scale,
      translation: Offset(matrix.entry(0, 3), matrix.entry(1, 3)),
    );
    if ((translation.dx - matrix.entry(0, 3)).abs() <= _zoomTolerance &&
        (translation.dy - matrix.entry(1, 3)).abs() <= _zoomTolerance) {
      return;
    }

    final constrained = Matrix4.copy(matrix);
    constrained[12] = translation.dx;
    constrained[13] = translation.dy;
    _controller.value = constrained;
  }

  void _handleControllerChanged() {
    if (_isConstrainingTransform) return;

    _isConstrainingTransform = true;
    // The image must stay fixed while its whole page is dragged, including
    // any image-pan momentum emitted after the pointer is released.
    if (_pageDragTransform != null) {
      _controller.value = Matrix4.copy(_pageDragTransform!);
    }
    _constrainCurrentTransform();
    _isConstrainingTransform = false;
    _refreshInteractionState();
    widget.onTransformChanged?.call(Matrix4.copy(_controller.value));
  }

  void _updatePageDrag(PointerMoveEvent event) {
    final pager = widget.pageController;
    if (!_isZoomed ||
        _hadMultiplePointers ||
        pager == null ||
        !pager.hasClients ||
        (!_panAccepted && _pageDrag == null)) {
      return;
    }

    final position = pager.position;
    final pageAxis = axisDirectionToAxis(position.axisDirection);
    // Global deltas stay stable while the page itself moves underneath us.
    final delta = event.delta;
    final primaryDelta = pageAxis == Axis.horizontal ? delta.dx : delta.dy;
    final crossDelta = pageAxis == Axis.horizontal ? delta.dy : delta.dx;
    if (_pageDrag == null) {
      if (primaryDelta.abs() <= crossDelta.abs() || primaryDelta == 0) return;
      final matrix = _controller.value;
      final scale = matrix.getMaxScaleOnAxis();
      final contentRect = _contentRect(_viewportSize);
      final bounds = pageAxis == Axis.horizontal
          ? _translationBounds(
              viewportExtent: _viewportSize.width,
              contentStart: contentRect.left,
              contentExtent: contentRect.width,
              scale: scale,
            )
          : _translationBounds(
              viewportExtent: _viewportSize.height,
              contentStart: contentRect.top,
              contentExtent: contentRect.height,
              scale: scale,
            );
      final translation =
          pageAxis == Axis.horizontal ? matrix.entry(0, 3) : matrix.entry(1, 3);
      final atBoundary = primaryDelta < 0
          ? translation <= bounds.min + _edgeTolerance
          : translation >= bounds.max - _edgeTolerance;
      if (!atBoundary) return;

      _pageDragTransform = Matrix4.copy(matrix);
      _pageDragOrigin = pager.page!.round() * position.viewportDimension;
      _pageDrag = position.drag(
        DragStartDetails(
          sourceTimeStamp: event.timeStamp,
          globalPosition: event.position,
        ),
        () => _pageDrag = null,
      );
    }

    final sign = axisDirectionIsReversed(position.axisDirection) ? 1.0 : -1.0;
    final extent = position.viewportDimension;
    final target = (position.pixels + primaryDelta * sign).clamp(
      (_pageDragOrigin - extent)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
      (_pageDragOrigin + extent)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    final consumedDelta = (target - position.pixels) / sign;
    _pageDrag?.update(DragUpdateDetails(
      sourceTimeStamp: event.timeStamp,
      globalPosition: event.position,
      delta: pageAxis == Axis.horizontal
          ? Offset(consumedDelta, 0)
          : Offset(0, consumedDelta),
      primaryDelta: consumedDelta,
    ));
  }

  void _finishPageDrag({required bool cancelled}) {
    final drag = _pageDrag;
    _pageDrag = null;
    if (drag == null) return;
    if (cancelled) {
      drag.cancel();
      return;
    }
    final position = widget.pageController!.position;
    final axis = axisDirectionToAxis(position.axisDirection);
    final velocity =
        _pageVelocity?.getVelocity().pixelsPerSecond ?? Offset.zero;
    var speed = axis == Axis.horizontal ? velocity.dx : velocity.dy;
    // One gesture cannot advance beyond its adjacent page.
    if ((position.pixels - _pageDragOrigin).abs() >=
            position.viewportDimension - _edgeTolerance ||
        speed.abs() < position.physics.minFlingVelocity) {
      speed = 0;
    }
    speed = speed.clamp(
        -position.physics.maxFlingVelocity, position.physics.maxFlingVelocity);
    drag.end(DragEndDetails(
      primaryVelocity: speed,
      velocity: Velocity(
          pixelsPerSecond:
              axis == Axis.horizontal ? Offset(speed, 0) : Offset(0, speed)),
    ));
  }

  void _cancelPageDrag() {
    final drag = _pageDrag;
    _pageDrag = null;
    drag?.cancel();
  }

  void _updateDoubleTapAnimation() {
    final animation = _doubleTapAnimation;
    if (animation == null) return;
    _controller.value = animation.value;
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
            if (_pointerPositions.length == 1) {
              _pageDragTransform = null;
              _panAccepted = false;
              _hadMultiplePointers = false;
              _pageVelocity = VelocityTracker.withKind(event.kind)
                ..addPosition(event.timeStamp, event.position);
            } else {
              _hadMultiplePointers = true;
              _cancelPageDrag();
              _pageDragTransform = null;
            }
            if (_pointerPositions.length == 2) _beginPinch();
            _refreshInteractionState();
          },
          onPointerMove: (event) => _updatePointer(event, constraints.biggest),
          onPointerUp: _endPointer,
          onPointerCancel: _endPointer,
          child: GestureDetector(
            // A paged image owns its double tap, so a gesture spanning page
            // changes cannot accidentally zoom a different progress index.
            onDoubleTapDown: widget.pageController == null
                ? null
                : (details) => _doubleTapPosition = details.globalPosition,
            onDoubleTap: widget.pageController == null
                ? null
                : () {
                    final position = _doubleTapPosition;
                    _doubleTapPosition = null;
                    if (position != null) _toggleDoubleTapZoom(position);
                  },
            onDoubleTapCancel: widget.pageController == null
                ? null
                : () => _doubleTapPosition = null,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: _minScale,
              maxScale: _maxScale,
              scaleEnabled: false,
              panEnabled: _isZoomed && !_hasMultiplePointers,
              onInteractionStart: (_) => _panAccepted = true,
              child: widget.pageController?.hasClients == true
                  ? ReaderPageGestureHandler(
                      controller: widget.pageController!,
                      scrollDirection: axisDirectionToAxis(
                        widget.pageController!.position.axisDirection,
                      ),
                      allowIdleDrag: !_isZoomed && !_hasMultiplePointers,
                      child: widget.child,
                    )
                  : widget.child,
            ),
          ),
        );
      },
    );
  }
}
