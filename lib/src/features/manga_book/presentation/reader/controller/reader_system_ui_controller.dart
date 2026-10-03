// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'reader_overlay_controller.dart';

// All chapter routes share ownership of fullscreen mode. Disposing an outgoing
// chapter must not restore system bars over the incoming chapter.
final readerSystemUiProvider = Provider.autoDispose<void>((ref) {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  ref.listen(readerOverlayVisibilityProvider, (_, visible) {
    if (!visible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  });
  ref.onDispose(() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  });
});
