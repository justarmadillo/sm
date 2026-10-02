/// Opens the study screen appropriate to one scheduled element type.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/daily_queue/study_scheduling.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/review/review_screen.dart';
import 'package:incremental_reader/features/video/video_screen.dart';
import 'package:incremental_reader/features/video/video_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';

/// Keeps mixed study sessions on one type-to-screen dispatch path.
///
/// [customDeckId] names the saved deck a session came from; only the review
/// log records it.
Future<StudyRouteResult> openStudyElement(
  BuildContext context,
  WidgetRef ref, {
  required ElementRef elementRef,
  StudyScheduling scheduling = StudyScheduling.scheduled,
  String? customDeckId,
}) => switch (elementRef.type) {
  ElementType.source => openReaderForStudy(
    context,
    ref,
    sourceId: elementRef.id,
    mode: scheduling.isPractice ? ReaderMode.practice : ReaderMode.scheduled,
  ),
  ElementType.extract => openExtract(
    context,
    ref,
    extractId: elementRef.id,
    mode: scheduling.isPractice ? ExtractMode.practice : ExtractMode.scheduled,
  ),
  ElementType.video => openVideoForStudy(
    context,
    ref,
    videoElementId: elementRef.id,
    mode: scheduling.isPractice ? VideoMode.practice : VideoMode.scheduled,
  ),
  ElementType.card => openReview(
    context,
    ref,
    cardId: elementRef.id,
    scheduling: scheduling,
    customDeckId: customDeckId,
  ),
};
