// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

class AnimatedImageDetector {
  const AnimatedImageDetector._();

  static const List<int> _gif87a = [71, 73, 70, 56, 55, 97];
  static const List<int> _gif89a = [71, 73, 70, 56, 57, 97];

  static Future<bool> isAnimated(File file) async {
    RandomAccessFile? randomAccessFile;
    try {
      randomAccessFile = await file.open();
      final header = await randomAccessFile.read(21);

      if (_startsWith(header, _gif87a) || _startsWith(header, _gif89a)) {
        return true;
      }
      if (_isAnimatedWebP(header)) return true;
      return false;
    } on FileSystemException {
      return false;
    } finally {
      await randomAccessFile?.close();
    }
  }

  static bool _isAnimatedWebP(List<int> header) =>
      header.length >= 21 &&
      _matchesAt(header, 0, const [82, 73, 70, 70]) &&
      _matchesAt(header, 8, const [87, 69, 66, 80]) &&
      _matchesAt(header, 12, const [86, 80, 56, 88]) &&
      (header[20] & 0x02) != 0;

  static bool _startsWith(List<int> bytes, List<int> prefix) =>
      _matchesAt(bytes, 0, prefix);

  static bool _matchesAt(List<int> bytes, int offset, List<int> expected) {
    if (bytes.length < offset + expected.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (bytes[offset + index] != expected[index]) return false;
    }
    return true;
  }
}
