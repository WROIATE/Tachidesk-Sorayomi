part of '../router_config.dart';

class HistoryBranch extends StatefulShellBranchData {
  const HistoryBranch();
  static final $initialLocation = const HistoryTabRoute().location;
}

class HistoryTabRoute extends GoRouteData {
  const HistoryTabRoute();
  @override
  Widget build(context, state) => const HistoryScreen();
}
