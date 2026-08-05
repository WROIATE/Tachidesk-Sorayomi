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

class ClearCacheTile extends ConsumerStatefulWidget {
  const ClearCacheTile({super.key});

  @override
  ConsumerState<ClearCacheTile> createState() => _ClearCacheTileState();
}

class _ClearCacheTileState extends ConsumerState<ClearCacheTile> {
  bool _isClearing = false;

  Future<void> _clearLocalImageCache() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  Future<void> _clearCache() async {
    if (_isClearing) return;

    setState(() => _isClearing = true);
    final toast = ref.read(toastProvider);
    final result = await AsyncValue.guard(
      () => Future.wait([
        ref.read(settingsRepositoryProvider).clearCachedImages(),
        _clearLocalImageCache(),
      ]),
    );

    if (!mounted) return;
    setState(() => _isClearing = false);

    if (result.hasError) {
      result.showToastOnError(toast);
    } else {
      toast?.show(context.l10n.cacheCleared);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: !_isClearing,
      leading: const Icon(Icons.cleaning_services_rounded),
      title: Text(context.l10n.clearCache),
      trailing: _isClearing
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isClearing ? null : _clearCache,
    );
  }
}
