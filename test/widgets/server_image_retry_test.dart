import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/widgets/server_image.dart';

void main() {
  test('failed server image retries once after refresh settles', () async {
    final refresh = Completer<void>();
    final coordinator = ServerImageRetryCoordinator();
    var retries = 0;

    final firstAttempt = coordinator.retryAfter(
      barrier: refresh.future,
      retry: () => retries++,
    );
    final duplicateAttempt = coordinator.retryAfter(
      barrier: refresh.future,
      retry: () => retries++,
    );

    await duplicateAttempt;
    expect(coordinator.hasRetried, isTrue);
    expect(retries, 0);

    refresh.complete();
    await firstAttempt;
    expect(retries, 1);

    await coordinator.retryAfter(
      barrier: Future<void>.value(),
      retry: () => retries++,
    );
    expect(retries, 1);
  });

  test('failed refresh still releases the single image retry', () async {
    final coordinator = ServerImageRetryCoordinator();
    var retries = 0;

    await coordinator.retryAfter(
      barrier: Future<void>.error(StateError('refresh failed')),
      retry: () => retries++,
    );

    expect(retries, 1);
  });
}
