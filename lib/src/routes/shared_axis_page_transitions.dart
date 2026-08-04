import 'package:flutter/material.dart';

/// A horizontal Material Shared Axis transition matching Mihon's navigation.
class SharedAxisXPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisXPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _SharedAxisXTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
}

class _SharedAxisXTransition extends StatelessWidget {
  const _SharedAxisXTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  static const _slideDistance = 30.0;
  static const _fadeThreshold = 0.35;
  static const _linearOutSlowIn = Cubic(0.0, 0.0, 0.2, 1.0);
  static const _fastOutLinearIn = Cubic(0.4, 0.0, 1.0, 1.0);

  static final Animatable<double> _incomingOpacity = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).chain(
    CurveTween(
      curve: const Interval(
        _fadeThreshold,
        1.0,
        curve: _linearOutSlowIn,
      ),
    ),
  );

  static final Animatable<double> _outgoingOpacity = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).chain(
    CurveTween(
      curve: const Interval(
        0.0,
        _fadeThreshold,
        curve: _fastOutLinearIn,
      ),
    ),
  );

  static final Animatable<double> _incomingFromRight = Tween<double>(
    begin: _slideDistance,
    end: 0.0,
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  static final Animatable<double> _outgoingToRight = Tween<double>(
    begin: 0.0,
    end: _slideDistance,
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  static final Animatable<double> _incomingFromLeft = Tween<double>(
    begin: -_slideDistance,
    end: 0.0,
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  static final Animatable<double> _outgoingToLeft = Tween<double>(
    begin: 0.0,
    end: -_slideDistance,
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) => _SlideFadeTransition(
        animation: animation,
        offset: _incomingFromRight,
        opacity: _incomingOpacity,
        child: child,
      ),
      reverseBuilder: (context, animation, child) => IgnorePointer(
        ignoring: animation.status == AnimationStatus.forward,
        child: _SlideFadeTransition(
          animation: animation,
          offset: _outgoingToRight,
          opacity: _outgoingOpacity,
          child: child,
        ),
      ),
      child: DualTransitionBuilder(
        animation: ReverseAnimation(secondaryAnimation),
        forwardBuilder: (context, animation, child) => _SlideFadeTransition(
          animation: animation,
          offset: _incomingFromLeft,
          opacity: _incomingOpacity,
          child: child,
        ),
        reverseBuilder: (context, animation, child) => _SlideFadeTransition(
          animation: animation,
          offset: _outgoingToLeft,
          opacity: _outgoingOpacity,
          child: child,
        ),
        child: child,
      ),
    );
  }
}

class _SlideFadeTransition extends StatelessWidget {
  const _SlideFadeTransition({
    required this.animation,
    required this.offset,
    required this.opacity,
    required this.child,
  });

  final Animation<double> animation;
  final Animatable<double> offset;
  final Animatable<double> opacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final offsetAnimation = animation.drive(offset);
    return FadeTransition(
      opacity: animation.drive(opacity),
      child: AnimatedBuilder(
        animation: offsetAnimation,
        builder: (context, child) => Transform.translate(
          offset: Offset(offsetAnimation.value, 0.0),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
