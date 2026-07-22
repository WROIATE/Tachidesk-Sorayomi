import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/routes/router_config.dart';

void main() {
  test('reader route serializes the start-at-end intent', () {
    final location = ReaderRoute(
      mangaId: 1,
      chapterId: 2,
      startAtEnd: true,
    ).location;

    expect(Uri.parse(location).queryParameters['start-at-end'], 'true');
  });

  test('reader route keeps normal chapter opens at the default position', () {
    final location = const ReaderRoute(mangaId: 1, chapterId: 2).location;

    expect(
        Uri.parse(location).queryParameters, isNot(contains('start-at-end')));
  });
}
