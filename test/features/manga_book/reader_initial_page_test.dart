import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/utils/reader_initial_page.dart';

void main() {
  group('resolveInitialReaderPage', () {
    test('opens the previous chapter at its last page', () {
      expect(
        resolveInitialReaderPage(
          startAtEnd: true,
          isRead: true,
          lastPageRead: 0,
          pageCount: 12,
        ),
        11,
      );
    });

    test('opens a completed chapter normally at its first page', () {
      expect(
        resolveInitialReaderPage(
          startAtEnd: false,
          isRead: true,
          lastPageRead: 11,
          pageCount: 12,
        ),
        0,
      );
    });

    test('restores progress for an unfinished chapter', () {
      expect(
        resolveInitialReaderPage(
          startAtEnd: false,
          isRead: false,
          lastPageRead: 5,
          pageCount: 12,
        ),
        5,
      );
    });

    test('keeps the initial page within the loaded page range', () {
      expect(
        resolveInitialReaderPage(
          startAtEnd: false,
          isRead: false,
          lastPageRead: 20,
          pageCount: 12,
        ),
        11,
      );
      expect(
        resolveInitialReaderPage(
          startAtEnd: true,
          isRead: false,
          lastPageRead: 0,
          pageCount: 0,
        ),
        0,
      );
    });
  });
}
