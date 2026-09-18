// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/services.dart';

class ReaderPageActionsPlatform {
  const ReaderPageActionsPlatform({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _channel = channel;

  static const String _channelName =
      'com.suwayomi.tachidesk_sorayomi/reader_page_actions';

  final MethodChannel _channel;

  Future<void> copyImage(String filePath) =>
      _channel.invokeMethod<void>('copyImage', {'filePath': filePath});

  Future<void> shareImage({
    required String filePath,
    required String message,
  }) =>
      _channel.invokeMethod<void>('shareImage', {
        'filePath': filePath,
        'message': message,
      });

  Future<void> saveImage({
    required String filePath,
    required String displayName,
  }) =>
      _channel.invokeMethod<void>('saveImage', {
        'filePath': filePath,
        'displayName': displayName,
      });
}

String readerPageFileName({
  required String mangaTitle,
  required String chapterTitle,
  required int pageNumber,
}) {
  final sanitized = '$mangaTitle - $chapterTitle - $pageNumber'
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .trim();
  return sanitized.isEmpty ? 'Sorayomi-$pageNumber' : sanitized;
}
