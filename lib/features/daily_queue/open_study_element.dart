/// Opens the study screen appropriate to one scheduled element type.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/review/review_screen.dart';
import 'package:incremental_reader/features/video/video_screen.dart';
import 'package:incremental_reader/scheduling/element.dart';

/// Keeps mixed study sessions on one type-to-screen dispatch path.
Future<StudyRouteResult> openStudyElement(
  BuildContext context,
  WidgetRef ref, {
  required ElementRef elementRef,
  bool isPractice = false,
}) => switch (elementRef.type) {
  ElementType.source => openReaderForStudy(
    context,
    ref,
    sourceId: elementRef.id,
    mode: ReaderMode.scheduled,
  ),
  ElementType.extract => openExtract(
    context,
    ref,
    extractId: elementRef.id,
    mode: ExtractMode.scheduled,
  ),
  ElementType.video => openVideoForStudy(
    context,
    ref,
    videoElementId: elementRef.id,
  ),
  ElementType.card => openReview(
    context,
    ref,
    cardId: elementRef.id,
    isPractice: isPractice,
  ),
};
