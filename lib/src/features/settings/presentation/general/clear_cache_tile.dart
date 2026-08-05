// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../data/settings_repository.dart';

class ClearCacheTiles extends ConsumerStatefulWidget {
  const ClearCacheTiles({super.key});

  @override
  ConsumerState<ClearCacheTiles> createState() => _ClearCacheTilesState();
}

enum _CacheTarget { server, client }

class _ClearCacheTilesState extends ConsumerState<ClearCacheTiles> {
  _CacheTarget? _clearingTarget;

  Future<void> _clearLocalImageCache() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  Future<void> _clearCache(_CacheTarget target) async {
    if (_clearingTarget != null) return;

    setState(() => _clearingTarget = target);
    final toast = ref.read(toastProvider);
    final result = await AsyncValue.guard(
      () => switch (target) {
        _CacheTarget.server =>
          ref.read(settingsRepositoryProvider).clearCachedImages(),
        _CacheTarget.client => _clearLocalImageCache(),
      },
    );

    if (!mounted) return;
    setState(() => _clearingTarget = null);

    if (result.hasError) {
      result.showToastOnError(toast);
    } else {
      toast?.show(context.l10n.cacheCleared);
    }
  }

  Future<void> _confirmAndClearCache(_CacheTarget target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_title(dialogContext, target)),
        content: Text(_description(dialogContext, target)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.clearCache),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) await _clearCache(target);
  }

  String _title(BuildContext context, _CacheTarget target) => switch (target) {
        _CacheTarget.server => context.l10n.clearServerCache,
        _CacheTarget.client => context.l10n.clearClientCache,
      };

  String _description(BuildContext context, _CacheTarget target) =>
      switch (target) {
        _CacheTarget.server => context.l10n.clearServerCacheDescription,
        _CacheTarget.client => context.l10n.clearClientCacheDescription,
      };

  Widget _buildTile(BuildContext context, _CacheTarget target) {
    final isClearing = _clearingTarget == target;
    final isEnabled = _clearingTarget == null;

    return ListTile(
      enabled: isEnabled,
      leading: Icon(
        switch (target) {
          _CacheTarget.server => Icons.dns_rounded,
          _CacheTarget.client => Icons.phone_android_rounded,
        },
      ),
      title: Text(_title(context, target)),
      subtitle: Text(_description(context, target)),
      trailing: isClearing
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: isEnabled ? () => _confirmAndClearCache(target) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTile(context, _CacheTarget.server),
        _buildTile(context, _CacheTarget.client),
      ],
    );
  }
}
