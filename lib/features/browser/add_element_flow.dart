/// Starts each standalone creation flow from the home screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/browser/import_sheet.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/extract/formulation_dialog.dart';
import 'package:incremental_reader/features/occlusion/occlusion_screen.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/video/import_video_sheet.dart';
import 'package:incremental_reader/features/video/video_screen.dart';
import 'package:incremental_reader/features/video/video_view_model.dart';

enum _StandaloneElementType { topic, markdownTopic, video, cards, occlusion }

/// Shows the Add choices on Home and carries the selected flow to completion.
Future<void> showAddElementFlow(BuildContext context, WidgetRef ref) async {
  final type = await showModalBottomSheet<_StandaloneElementType>(
    context: context,
    builder: (BuildContext context) => const SafeArea(
      child: Wrap(
        children: <Widget>[
          _AddChoice(
            type: _StandaloneElementType.topic,
            icon: Icons.article_outlined,
            label: 'Topic',
          ),
          _AddChoice(
            type: _StandaloneElementType.markdownTopic,
            icon: Icons.file_open_outlined,
            label: 'Topic from Markdown',
          ),
          _AddChoice(
            type: _StandaloneElementType.video,
            icon: Icons.smart_display_outlined,
            label: 'Video',
          ),
          _AddChoice(
            type: _StandaloneElementType.cards,
            icon: Icons.style_outlined,
            label: 'Cards',
          ),
          _AddChoice(
            type: _StandaloneElementType.occlusion,
            icon: Icons.image_outlined,
            label: 'Image occlusion',
          ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return;
  switch (type) {
    case _StandaloneElementType.topic:
      await _addTopic(context, ref, isWritten: true);
    case _StandaloneElementType.markdownTopic:
      await _addTopic(context, ref, isWritten: false);
    case _StandaloneElementType.video:
      await _addVideo(context, ref);
    case _StandaloneElementType.cards:
      await _addCards(context, ref);
    case _StandaloneElementType.occlusion:
      final image = await chooseOcclusionImage(context, ref);
      if (image != null && context.mounted) {
        await openOcclusionScreen(context, ref, image: image);
      }
  }
}

Future<void> _addTopic(
  BuildContext context,
  WidgetRef ref, {
  required bool isWritten,
}) async {
  final request = isWritten
      ? await showNewTopicSheet(context)
      : await showImportSheet(context);
  if (request == null || !context.mounted) return;
  final sourceId = await ref
      .read(browserViewModelProvider.notifier)
      .importMarkdown(title: request.title, markdown: request.markdown);
  if (sourceId == null || isWritten || !context.mounted) return;
  await openReader(
    context,
    ref,
    sourceId: sourceId,
    mode: ReaderMode.scheduled,
  );
}

Future<void> _addVideo(BuildContext context, WidgetRef ref) async {
  final request = await showImportVideoSheet(context);
  if (request == null || !context.mounted) return;
  final elementId = await ref
      .read(browserViewModelProvider.notifier)
      .importVideo(
        url: request.url,
        title: request.title,
        startSeconds: 0,
        endSeconds: request.durationSeconds,
        durationSeconds: request.durationSeconds,
        thumbnailUrl: request.thumbnailUrl,
      );
  if (elementId == null || !context.mounted) return;
  await openVideo(
    context,
    ref,
    videoElementId: elementId,
    mode: VideoMode.scheduled,
  );
}

Future<void> _addCards(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsStoreProvider).currentOrDefaults.cards;
  final List<CardDraft>? drafts = await showFormulationDialog(
    context,
    seedText: '',
    existingCardCount: 0,
    overlapContextBefore: settings.overlapContextBefore,
    overlapContextAfter: settings.overlapContextAfter,
    parentNoun: 'collection',
  );
  if (drafts == null || !context.mounted) return;
  await ref
      .read(browserViewModelProvider.notifier)
      .createCards(parent: null, drafts: drafts);
}

class _AddChoice extends StatelessWidget {
  const _AddChoice({
    required this.type,
    required this.icon,
    required this.label,
  });

  final _StandaloneElementType type;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.of(context).pop(type),
  );
}
