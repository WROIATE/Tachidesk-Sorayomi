part of '../router_config.dart';

//
class MangaRoute extends GoRouteData {
  const MangaRoute({required this.mangaId, this.categoryId});
  final int mangaId;
  final int? categoryId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      MangaDetailsScreen(mangaId: mangaId, categoryId: categoryId);
}

class UpdateStatusRoute extends GoRouteData {
  const UpdateStatusRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const UpdateStatusSummaryDialog();
}

class ReaderRoute extends GoRouteData {
  const ReaderRoute({
    required this.mangaId,
    required this.chapterId,
    this.transVertical,
    this.toPrev,
    this.startAtEnd = false,
    this.startAtBeginning = false,
    this.showReaderLayoutAnimation = false,
  }) : assert(!(startAtEnd && startAtBeginning));
  final int mangaId;
  final int chapterId;
  final bool? transVertical;
  final bool? toPrev;
  final bool startAtEnd;
  final bool startAtBeginning;
  final bool showReaderLayoutAnimation;

  static final $parentNavigatorKey = _quickOpenNavigatorKey;

  @override
  Page<void> buildPage(context, state) {
    final child = ReaderScreen(
      mangaId: mangaId,
      chapterId: chapterId,
      startAtEnd: startAtEnd,
      startAtBeginning: startAtBeginning,
      showReaderLayoutAnimation: showReaderLayoutAnimation,
    );
    final isChapterTransition = transVertical != null ||
        toPrev != null ||
        startAtEnd ||
        startAtBeginning;
    final offset = (transVertical.ifNull()
            ? const Offset(0, 1)
            : const Offset(1, 0)) *
        (toPrev.ifNull() ? -1 : 1);
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return ReaderCupertinoPage(
        key: state.pageKey,
        chapterEntryOffset: isChapterTransition ? offset : null,
        child: child,
      );
    }

    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return DualTransitionBuilder(
          animation: animation,
          forwardBuilder: (context, animation, child) => isChapterTransition
              ? SlideTransition(
                  position: Tween<Offset>(
                    begin: offset,
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                )
              : SharedAxisXPushEnterTransition(
                  animation: animation,
                  child: child,
                ),
          reverseBuilder: (context, animation, child) =>
              SharedAxisXPopExitTransition(
            animation: animation,
            child: child,
          ),
          child: child,
        );
      },
    );
  }
}

class GlobalSearchRoute extends GoRouteData {
  const GlobalSearchRoute({this.query});
  final String? query;

  static final $parentNavigatorKey = _quickOpenNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      GlobalSearchScreen(key: ValueKey(query), initialQuery: query);
}
