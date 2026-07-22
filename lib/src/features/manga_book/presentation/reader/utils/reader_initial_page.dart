int resolveInitialReaderPage({
  required bool startAtEnd,
  required bool isRead,
  required int lastPageRead,
  required int pageCount,
}) {
  if (pageCount <= 0) return 0;

  final requestedPage = startAtEnd
      ? pageCount - 1
      : isRead
          ? 0
          : lastPageRead;

  return requestedPage.clamp(0, pageCount - 1);
}
