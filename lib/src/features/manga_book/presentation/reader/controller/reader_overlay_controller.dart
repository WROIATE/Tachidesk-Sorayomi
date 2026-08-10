// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../settings/presentation/reader/widgets/reader_initial_overlay_tile/reader_initial_overlay_tile.dart';

part 'reader_overlay_controller.g.dart';

@riverpod
class ReaderOverlayVisibility extends _$ReaderOverlayVisibility {
  @override
  bool build() => ref.read(readerInitialOverlayProvider).ifNull();

  void toggle() => state = !state;
}
