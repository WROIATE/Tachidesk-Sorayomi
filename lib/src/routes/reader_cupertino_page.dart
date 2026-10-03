import 'package:flutter/cupertino.dart';

/// Keeps chapter entry direction independent of the iOS back gesture.
class ReaderCupertinoPage extends CupertinoPage<void> {
  const ReaderCupertinoPage({
    super.key,
    required super.child,
    this.chapterEntryOffset,
  });

  final Offset? chapterEntryOffset;

  @override
  Route<void> createRoute(BuildContext context) => _ReaderCupertinoRoute(this);
}

class _ReaderCupertinoRoute extends PageRoute<void>
    with CupertinoRouteTransitionMixin<void> {
  _ReaderCupertinoRoute(ReaderCupertinoPage page) : super(settings: page);

  ReaderCupertinoPage get _page => settings as ReaderCupertinoPage;

  // Chapter visuals animate inside the route so the route can accept page
  // gestures immediately. Regular reader entry keeps the native iOS timing.
  @override
  Duration get transitionDuration => _page.chapterEntryOffset == null
      ? super.transitionDuration
      : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      CupertinoRouteTransitionMixin.kTransitionDuration;

  @override
  Widget buildContent(BuildContext context) {
    final offset = _page.chapterEntryOffset;
    return offset == null
        ? _page.child
        : _ChapterEntryTransition(offset: offset, child: _page.child);
  }

  @override
  String? get title => _page.title;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Chapter replacement must not also drag the old chapter left with the
    // standard Cupertino parallax, especially when going to a previous chapter.
    if (nextRoute is _ReaderCupertinoRoute &&
        nextRoute._page.chapterEntryOffset != null) {
      return false;
    }
    return super.canTransitionTo(nextRoute);
  }
}

class _ChapterEntryTransition extends StatefulWidget {
  const _ChapterEntryTransition({
    required this.offset,
    required this.child,
  });

  final Offset offset;
  final Widget child;

  @override
  State<_ChapterEntryTransition> createState() =>
      _ChapterEntryTransitionState();
}

class _ChapterEntryTransitionState extends State<_ChapterEntryTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: CupertinoRouteTransitionMixin.kTransitionDuration,
    vsync: this,
  )..forward();
  late final Animation<Offset> _position = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _position,
        transformHitTests: false,
        child: widget.child,
      );
}
