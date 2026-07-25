// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../constants/app_sizes.dart';
import '../constants/endpoints.dart';
import '../constants/enum.dart';
import '../features/settings/presentation/server/widget/client/server_port_tile/server_port_tile.dart';
import '../features/settings/presentation/server/widget/client/server_url_tile/server_url_tile.dart';
import '../features/settings/presentation/server/widget/credential_popup/credentials_popup.dart';
import '../global_providers/global_providers.dart';
import '../utils/animated_image_file_loader.dart';
import '../utils/extensions/custom_extensions.dart';
import '../utils/misc/app_utils.dart';
import 'custom_circular_progress_indicator.dart';
import 'flutter_codec_animated_image.dart';

class ServerImageRetryCoordinator {
  bool _hasRetried = false;

  bool get hasRetried => _hasRetried;

  Future<void> retryAfter({
    required Future<void> barrier,
    required VoidCallback retry,
  }) async {
    if (_hasRetried) return;
    _hasRetried = true;

    try {
      await barrier;
    } catch (_) {
      // The image should still get its single retry after refresh settles.
    }
    retry();
  }
}

class ServerImage extends HookConsumerWidget {
  const ServerImage({
    super.key,
    required this.imageUrl,
    this.size,
    this.fit,
    this.appendApiToUrl = false,
    this.progressIndicatorBuilder,
    this.wrapper,
    this.showReloadButton = false,
    this.retryAfterFailure,
    this.preferFlutterCodecAnimation = false,
    this.isAnimationActive = true,
  });

  final String imageUrl;
  final Size? size;
  final BoxFit? fit;
  final bool appendApiToUrl;
  final Widget Function(BuildContext, String, DownloadProgress)?
  progressIndicatorBuilder;
  final Widget Function(Widget child)? wrapper;
  final bool showReloadButton;
  final Future<void>? retryAfterFailure;
  final bool preferFlutterCodecAnimation;
  final bool isAnimationActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = useState(UniqueKey());
    final isWaitingToRetry = useState(false);
    final cacheManager = useMemoized(DefaultCacheManager.new);
    final retryCoordinator = useMemoized(ServerImageRetryCoordinator.new, [
      imageUrl,
      retryAfterFailure,
    ]);
    // Providers
    final authType = ref.watch(authTypeKeyProvider);
    final basicToken = ref.watch(credentialsProvider);
    final isUiLogin = authType == AuthType.uiLogin;
    final accessToken = isUiLogin
        ? ref.watch(
            authSessionProvider.select((session) => session.accessToken),
          )
        : null;
    final isUiLoggedIn =
        isUiLogin &&
        ref.watch(authSessionProvider.select((session) => session.isLoggedIn));

    useEffect(() {
      if (isUiLoggedIn && accessToken == null) {
        unawaited(ref.read(authSessionProvider).refreshInBackground());
      }
      return null;
    }, [isUiLoggedIn, accessToken]);

    final baseApi =
        "${Endpoints.baseApi(baseUrl: ref.watch(serverUrlProvider), port: ref.watch(serverPortProvider), addPort: ref.watch(serverPortToggleProvider).ifNull(), appendApiToUrl: appendApiToUrl)}"
        "$imageUrl";

    final authorization = switch (authType) {
      AuthType.basic when basicToken != null => basicToken,
      AuthType.uiLogin when accessToken != null => 'Bearer $accessToken',
      _ => null,
    };
    final httpHeaders = authorization == null
        ? null
        : <String, String>{'Authorization': authorization};
    final canLoadImage = !isUiLoggedIn || accessToken != null;
    final animationFile = useMemoized<Future<String?>?>(
      () {
        if (!preferFlutterCodecAnimation || !canLoadImage) return null;
        return loadAnimatedImageFile(
          cacheManager: cacheManager,
          url: baseApi,
          headers: httpHeaders,
        );
      },
      [
        baseApi,
        authorization,
        preferFlutterCodecAnimation,
        canLoadImage,
        key.value,
      ],
    );
    final animationFileSnapshot = useFuture(
      animationFile,
      preserveState: false,
    );

    final ImageRenderMethodForWeb renderMethod;
    if (authorization != null) {
      renderMethod = ImageRenderMethodForWeb.HttpGet;
    } else {
      renderMethod = ImageRenderMethodForWeb.HtmlImage;
    }

    finalProgressIndicatorBuilder(
      BuildContext context,
      String url,
      DownloadProgress progress,
    ) => AppUtils.wrapOn(
      wrapper,
      progressIndicatorBuilder?.call(context, url, progress) ??
          const CenterSorayomiShimmerIndicator(),
    );

    Widget errorContent(BuildContext context) {
      if (isWaitingToRetry.value) {
        return const CenterSorayomiShimmerIndicator();
      }
      if (showReloadButton) {
        return Padding(
          padding: KEdgeInsets.a8.size,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_rounded, color: Colors.grey),
                const Gap(32),
                TextButton(
                  onPressed: () {
                    key.value = (UniqueKey());
                  },
                  child: Text(context.l10n.reload),
                ),
              ],
            ),
          ),
        );
      } else {
        return const Icon(Icons.broken_image_rounded, color: Colors.grey);
      }
    }

    Widget errorWidget(BuildContext context, String error, stackTrace) {
      return AppUtils.wrapOn(wrapper, errorContent(context));
    }

    if (isUiLoggedIn && accessToken == null) {
      return AppUtils.wrapOn(wrapper, const CenterSorayomiShimmerIndicator());
    }

    void retryOnFailure(Object _) {
      final barrier = retryAfterFailure;
      if (barrier == null || retryCoordinator.hasRetried) return;
      isWaitingToRetry.value = true;

      unawaited(
        retryCoordinator.retryAfter(
          barrier: barrier,
          retry: () {
            if (context.mounted) {
              isWaitingToRetry.value = false;
              key.value = UniqueKey();
            }
          },
        ),
      );
    }

    if (animationFile != null) {
      if (animationFileSnapshot.connectionState != ConnectionState.done) {
        return AppUtils.wrapOn(wrapper, const CenterSorayomiShimmerIndicator());
      }
      if (animationFileSnapshot.hasError) {
        return errorWidget(context, baseApi, animationFileSnapshot.error);
      }
      final animatedFilePath = animationFileSnapshot.data;
      if (animatedFilePath != null) {
        final targetWidth =
            (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .ceil();
        return AppUtils.wrapOn(
          wrapper,
          FlutterCodecAnimatedImage(
            key: key.value,
            filePath: animatedFilePath,
            fit: fit ?? BoxFit.cover,
            active: isAnimationActive,
            targetWidth: targetWidth,
            errorBuilder: errorContent,
          ),
        );
      }
    }

    return CachedNetworkImage(
      key: key.value,
      imageUrl: baseApi,
      height: size?.height,
      cacheManager: cacheManager,
      httpHeaders: httpHeaders,
      width: size?.width,
      fit: fit ?? BoxFit.cover,
      imageRenderMethodForWeb: renderMethod,
      progressIndicatorBuilder: finalProgressIndicatorBuilder,
      errorWidget: errorWidget,
      errorListener: retryOnFailure,
    );
  }
}

class ServerImageWithCpi extends StatelessWidget {
  const ServerImageWithCpi({
    super.key,
    required this.url,
    required this.outerSize,
    required this.innerSize,
    required this.isLoading,
  });
  final bool isLoading;
  final Size outerSize;
  final Size innerSize;
  final String url;
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox.fromSize(
        size: outerSize,
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(4.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            ServerImage(
              imageUrl: url,
              size: innerSize,
              progressIndicatorBuilder: (context, url, progress) =>
                  const CenterSorayomiShimmerIndicator(),
            ),
          ],
        ),
      );
    } else {
      return ServerImage(imageUrl: url, size: outerSize);
    }
  }
}
