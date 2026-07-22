// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import '../../../domain/chapter_batch/chapter_batch_model.dart';

class ReaderProgressUpdate {
  const ReaderProgressUpdate({
    required this.pageIndex,
    required this.isCompleted,
  });

  final int pageIndex;
  final bool isCompleted;

  ChapterChange toChapterChange() => ChapterChange(
        lastPageRead: pageIndex,
        isRead: isCompleted,
      );
}

class ReaderProgressSaver {
  ReaderProgressSaver({
    required Future<void> Function(ReaderProgressUpdate progress) save,
    this.delay = const Duration(seconds: 2),
  }) : _save = save;

  final Future<void> Function(ReaderProgressUpdate progress) _save;
  final Duration delay;

  Timer? _timer;
  ReaderProgressUpdate? _pending;
  Future<void> _queuedSave = Future<void>.value();

  void schedule(ReaderProgressUpdate progress) {
    _pending = progress;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> saveImmediately(ReaderProgressUpdate progress) {
    _pending = progress;
    return flush();
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;

    final progress = _pending;
    if (progress == null) return _queuedSave;
    _pending = null;

    final operation = _queuedSave.then((_) => _save(progress));
    _queuedSave = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}
