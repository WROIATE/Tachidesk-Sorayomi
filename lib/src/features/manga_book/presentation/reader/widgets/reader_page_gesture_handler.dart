// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// For animation takeover, place outside Scrollable's IgnorePointer. Inside
/// an unzoomed image, [allowIdleDrag] gives page dragging priority over scaling.
class ReaderPageGestureHandler extends StatefulWidget {
  const ReaderPageGestureHandler({
    super.key,
    required this.controller,
    required this.scrollDirection,
    required this.child,
    this.allowIdleDrag = false,
  });

  final PageController controller;
  final Axis scrollDirection;
  final Widget child;

  /// Used inside the image recognizer so unzoomed page drags win the arena.
  final bool allowIdleDrag;

  @override
  State<ReaderPageGestureHandler> createState() =>
      _ReaderPageGestureHandlerState();
}

class _ReaderPageGestureHandlerState extends State<ReaderPageGestureHandler> {
  ScrollHoldController? _hold;
  Drag? _drag;
  final Set<int> _pointers = {};
  bool _hadMultiplePointers = false;
  double _origin = 0;
  bool _idleDrag = false;

  bool _canCatch() {
    if (_pointers.isNotEmpty || !widget.controller.hasClients) return false;
    _hadMultiplePointers = false;
    // Scrolling with no fingers down is settling/programmatic motion. Use the
    // public notifier rather than depending on ScrollPosition's activity.
    return widget.allowIdleDrag ||
        widget.controller.position.isScrollingNotifier.value;
  }

  void _down(DragDownDetails details) {
    if (_hadMultiplePointers || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    _idleDrag = widget.allowIdleDrag;
    if (!_idleDrag && !position.isScrollingNotifier.value) return;
    _origin = widget.controller.page!.round() * position.viewportDimension;
    _hold = position.hold(() => _hold = null);
  }

  void _start(DragStartDetails details) {
    // PageView may replace our hold before losing the arena. An idle drag
    // still owns this gesture and can start the native scroll activity.
    if ((_hold == null && !_idleDrag) || _hadMultiplePointers) return;
    _drag = widget.controller.position.drag(details, () => _drag = null);
  }

  void _update(DragUpdateDetails details) {
    if (_drag == null || _hadMultiplePointers) return;
    final position = widget.controller.position;
    final sign = axisDirectionIsReversed(position.axisDirection) ? 1.0 : -1.0;
    final extent = position.viewportDimension;
    final target = (position.pixels + details.primaryDelta! * sign).clamp(
      (_origin - extent)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
      (_origin + extent)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    final delta = (target - position.pixels) / sign;
    _drag!.update(DragUpdateDetails(
      sourceTimeStamp: details.sourceTimeStamp,
      globalPosition: details.globalPosition,
      delta: widget.scrollDirection == Axis.horizontal
          ? Offset(delta, 0)
          : Offset(0, delta),
      primaryDelta: delta,
    ));
  }

  void _end(DragEndDetails details) {
    final drag = _drag;
    _drag = null;
    if (drag == null) {
      _cancel();
      return;
    }
    final position = widget.controller.position;
    var speed = details.primaryVelocity ?? 0;
    if ((position.pixels - _origin).abs() >= position.viewportDimension - 1 ||
        speed.abs() < position.physics.minFlingVelocity) {
      speed = 0;
    }
    speed = speed.clamp(
        -position.physics.maxFlingVelocity, position.physics.maxFlingVelocity);
    drag.end(DragEndDetails(
      primaryVelocity: speed,
      velocity: Velocity(
        pixelsPerSecond: widget.scrollDirection == Axis.horizontal
            ? Offset(speed, 0)
            : Offset(0, speed),
      ),
    ));
  }

  void _cancel() {
    final drag = _drag;
    final hold = _hold;
    _drag = null;
    _hold = null;
    _idleDrag = false;
    drag?.cancel();
    hold?.cancel();
  }

  @override
  void didUpdateWidget(covariant ReaderPageGestureHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.scrollDirection != widget.scrollDirection) {
      _cancel();
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.scrollDirection == Axis.horizontal;
    return Listener(
      onPointerDown: (event) {
        if (_pointers.isEmpty) _hadMultiplePointers = false;
        _pointers.add(event.pointer);
        if (_pointers.length > 1) {
          _hadMultiplePointers = true;
          _cancel();
        }
      },
      onPointerUp: (event) => _pointers.remove(event.pointer),
      onPointerCancel: (event) => _pointers.remove(event.pointer),
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          if (horizontal)
            _SettlingHorizontalDrag:
                GestureRecognizerFactoryWithHandlers<_SettlingHorizontalDrag>(
              () => _SettlingHorizontalDrag(_canCatch),
              _configure,
            )
          else
            _SettlingVerticalDrag:
                GestureRecognizerFactoryWithHandlers<_SettlingVerticalDrag>(
              () => _SettlingVerticalDrag(_canCatch),
              _configure,
            ),
        },
        child: widget.child,
      ),
    );
  }

  void _configure(DragGestureRecognizer recognizer) {
    recognizer
      ..onDown = _down
      ..onStart = _start
      ..onUpdate = _update
      ..onEnd = _end
      ..onCancel = _cancel;
  }
}

// Idle entry is explicitly enabled only inside an unzoomed image. The outer
// animation-catch handler must not compete with image panning or pinching.
class _SettlingHorizontalDrag extends HorizontalDragGestureRecognizer {
  _SettlingHorizontalDrag(this.canCatch);
  final bool Function() canCatch;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      canCatch() && super.isPointerAllowed(event);
}

class _SettlingVerticalDrag extends VerticalDragGestureRecognizer {
  _SettlingVerticalDrag(this.canCatch);
  final bool Function() canCatch;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      canCatch() && super.isPointerAllowed(event);
}
