// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../utils/reader_page_actions_platform.dart';

Future<void> showReaderPageActionsSheet(
  BuildContext context, {
  required String filePath,
  required String mangaTitle,
  required String chapterTitle,
  required int pageNumber,
  ReaderPageActionsPlatform platform = const ReaderPageActionsPlatform(),
}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => ReaderPageActionsSheet(
        filePath: filePath,
        mangaTitle: mangaTitle,
        chapterTitle: chapterTitle,
        pageNumber: pageNumber,
        platform: platform,
        feedbackContext: context,
      ),
    );

class ReaderPageActionsSheet extends StatelessWidget {
  const ReaderPageActionsSheet({
    super.key,
    required this.filePath,
    required this.mangaTitle,
    required this.chapterTitle,
    required this.pageNumber,
    required this.platform,
    required this.feedbackContext,
  });

  final String filePath;
  final String mangaTitle;
  final String chapterTitle;
  final int pageNumber;
  final ReaderPageActionsPlatform platform;
  final BuildContext feedbackContext;

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    Navigator.pop(context);
    try {
      await action();
      if (successMessage != null && feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (_) {
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          SnackBar(content: Text(feedbackContext.l10n.errorSomethingWentWrong)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = readerPageFileName(
      mangaTitle: mangaTitle,
      chapterTitle: chapterTitle,
      pageNumber: pageNumber,
    );
    final shareMessage = '$mangaTitle · $chapterTitle · $pageNumber';

    return SafeArea(
      key: const ValueKey('reader-page-actions'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            _PageActionButton(
              icon: Icons.content_copy_rounded,
              label: context.l10n.copyImage,
              onPressed: () => _runAction(
                context,
                () => platform.copyImage(filePath),
                successMessage: feedbackContext.l10n.copied,
              ),
            ),
            _PageActionButton(
              icon: Icons.share_rounded,
              label: context.l10n.share,
              onPressed: () => _runAction(
                context,
                () => platform.shareImage(
                  filePath: filePath,
                  message: shareMessage,
                ),
              ),
            ),
            _PageActionButton(
              icon: Icons.save_alt_rounded,
              label: context.l10n.save,
              onPressed: () => _runAction(
                context,
                () => platform.saveImage(
                  filePath: filePath,
                  displayName: displayName,
                ),
                successMessage: feedbackContext.l10n.imageSaved,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageActionButton extends StatelessWidget {
  const _PageActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
        child: TextButton(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
