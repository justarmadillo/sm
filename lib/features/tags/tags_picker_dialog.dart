/// A reusable picker for choosing the direct tags of elements.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/features/tags/tags_providers.dart';
import 'package:incremental_reader/features/tags/tags_screen.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// Shows every tag and returns the selected ids, or null when cancelled.
Future<Set<String>?> showTagsPicker(
  BuildContext context,
  WidgetRef ref, {
  Set<String> initialTagIds = const <String>{},
  String title = 'Tags',
}) async {
  final List<Tag> tags = await ref.read(tagRepositoryProvider).listTags();
  if (!context.mounted) return null;
  return showDialog<Set<String>>(
    context: context,
    builder: (BuildContext context) => _TagsPickerDialog(
      title: title,
      tags: tags,
      initialTagIds: initialTagIds,
    ),
  );
}

/// Picks and saves the direct tags of one element.
Future<bool> editTagsOfElement(
  BuildContext context,
  WidgetRef ref,
  ElementRef elementRef,
) async {
  final Set<String> current = (await ref
      .read(tagRepositoryProvider)
      .listTagIdsOfElement(elementRef)).toSet();
  if (!context.mounted) return false;
  final Set<String>? chosen = await showTagsPicker(
    context,
    ref,
    initialTagIds: current,
  );
  if (chosen == null || !context.mounted) return false;
  final result = await ref.read(tagsCommandRunnerProvider).save(
    SaveTagsOfElement(
      OperationId(ref.read(idGeneratorProvider).newId()),
      ref: elementRef,
      tagIds: chosen,
    ),
  );
  if (result.isErr && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.failureOrNull!.message)),
    );
  }
  return result.isOk;
}

class _TagsPickerDialog extends StatefulWidget {
  const _TagsPickerDialog({
    required this.title,
    required this.tags,
    required this.initialTagIds,
  });

  final String title;
  final List<Tag> tags;
  final Set<String> initialTagIds;

  @override
  State<_TagsPickerDialog> createState() => _TagsPickerDialogState();
}

class _TagsPickerDialogState extends State<_TagsPickerDialog> {
  late final Set<String> _selected = <String>{...widget.initialTagIds};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: widget.tags.isEmpty
          ? const Text('No tags yet. Create one from the Tags screen.')
          : ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final Tag tag in widget.tags)
                  CheckboxListTile(
                    value: _selected.contains(tag.id),
                    title: Text('#${tag.name}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? selected) => setState(() {
                      if (selected ?? false) {
                        _selected.add(tag.id);
                      } else {
                        _selected.remove(tag.id);
                      }
                    }),
                  ),
              ],
            ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () async {
          await openTags(context);
          if (context.mounted) Navigator.of(context).pop();
        },
        child: const Text('Manage tags'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: const Text('Apply'),
      ),
    ],
  );
}
