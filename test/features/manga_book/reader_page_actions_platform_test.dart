import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/utils/reader_page_actions_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/reader_page_actions');
  const platform = ReaderPageActionsPlatform(channel: channel);
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends image actions through the reader platform channel', () async {
    await platform.copyImage('/cache/page');
    await platform.shareImage(filePath: '/cache/page', message: 'Chapter 1');
    await platform.saveImage(filePath: '/cache/page', displayName: 'Page 1');

    expect(calls, hasLength(3));
    expect(calls[0].method, 'copyImage');
    expect(calls[0].arguments, {'filePath': '/cache/page'});
    expect(calls[1].method, 'shareImage');
    expect(calls[1].arguments, {
      'filePath': '/cache/page',
      'message': 'Chapter 1',
    });
    expect(calls[2].method, 'saveImage');
    expect(calls[2].arguments, {
      'filePath': '/cache/page',
      'displayName': 'Page 1',
    });
  });

  test('sanitizes reader page file names', () {
    expect(
      readerPageFileName(
        mangaTitle: 'Manga: title',
        chapterTitle: 'Chapter/1',
        pageNumber: 7,
      ),
      'Manga_ title - Chapter_1 - 7',
    );
  });
}
