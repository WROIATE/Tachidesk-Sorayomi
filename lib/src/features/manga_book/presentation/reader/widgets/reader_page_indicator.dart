// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

class ReaderPageIndicator extends StatelessWidget {
  const ReaderPageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    if (currentPage <= 0 || totalPages <= 0) return const SizedBox.shrink();

    final text = '$currentPage / $totalPages';
    final baseStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
          color: const Color(0xFFEBEBEB),
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        );

    return Semantics(
      label: text,
      child: Stack(
        key: const ValueKey('reader-page-indicator'),
        alignment: Alignment.center,
        children: [
          Text(
            text,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = const Color(0xFF2D2D2D),
            ),
          ),
          Text(text, style: baseStyle),
        ],
      ),
    );
  }
}
