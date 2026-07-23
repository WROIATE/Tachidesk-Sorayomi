part of '../router_config.dart';

class DownloadsBranch extends StatefulShellBranchData {
  const DownloadsBranch();
}

class DownloadsRoute extends GoRouteData {
  const DownloadsRoute();
  @override
  Widget build(context, state) => const DownloadsScreen();
}

class DownloadedMangaRoute extends GoRouteData {
  const DownloadedMangaRoute({required this.mangaId});

  final int mangaId;

  @override
  Widget build(context, state) => DownloadedMangaScreen(mangaId: mangaId);
}
