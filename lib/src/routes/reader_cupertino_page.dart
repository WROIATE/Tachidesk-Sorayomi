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
  bool _hasEntered = false;

  @override
  Widget buildContent(BuildContext context) => _page.child;

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

  @override
  void install() {
    super.install();
    // The route animation can report completion during offstage layout.
    // Only the controller tracks the actual chapter entry lifecycle.
    controller!.addStatusListener(_trackEntry);
  }

  void _trackEntry(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _hasEntered = true;
    }
  }

  @override
  void dispose() {
    controller!.removeStatusListener(_trackEntry);
    super.dispose();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final offset = _page.chapterEntryOffset;
    final enteringChapter = offset != null && !_hasEntered;
    // Keep the widget tree stable when entry finishes, so reader state survives.
    // Subsequent forward animation (a cancelled back swipe) stays Cupertino.
    return super.buildTransitions(
      context,
      enteringChapter ? kAlwaysCompleteAnimation : animation,
      secondaryAnimation,
      SlideTransition(
        position: Tween<Offset>(begin: offset ?? Offset.zero, end: Offset.zero)
            .animate(enteringChapter ? animation : kAlwaysCompleteAnimation),
        child: child,
      ),
    );
  }
}
