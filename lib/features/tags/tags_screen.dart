/// The screen for creating, renaming, and deleting flat tags.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/features/tags/tags_providers.dart';
import 'package:incremental_reader/features/tags/tags_query.dart';
import 'package:incremental_reader/features/tags/tags_view_model.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';

/// Opens the Tags screen and waits until it closes.
Future<void> openTags(BuildContext context) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(builder: (_) => const TagsScreen()),
);

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  late Future<List<TagListEntry>> _entries;

  TagsViewModel get _model => TagsViewModel(
    ref.read(tagsCommandRunnerProvider),
    () => OperationId(ref.read(idGeneratorProvider).newId()),
  );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _entries = ref.read(tagsQueryProvider).load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tags')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _editName,
      icon: const Icon(Icons.add),
      label: const Text('New tag'),
    ),
    body: FutureBuilder<List<TagListEntry>>(
      future: _entries,
      builder: (BuildContext context, AsyncSnapshot<List<TagListEntry>> snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<TagListEntry> entries = snap.data!;
        if (entries.isEmpty) {
          return const Center(child: Text('No tags yet.'));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (BuildContext context, int index) {
            final TagListEntry entry = entries[index];
            return ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text('#${entry.tag.name}'),
              subtitle: Text('${entry.elementCount} elements'),
              onTap: () => _editName(entry: entry),
              trailing: IconButton(
                tooltip: 'Delete tag',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(entry),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _editName({TagListEntry? entry}) async {
    final TextEditingController controller = TextEditingController(
      text: entry?.tag.name ?? '',
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(entry == null ? 'New tag' : 'Rename tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '#'),
          onSubmitted: (String value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    final Result<TagOutcome> result = entry == null
        ? await _model.create(name)
        : await _model.rename(entry.tag, name);
    if (!mounted) return;
    _showFailure(result);
    setState(_reload);
  }

  Future<void> _delete(TagListEntry entry) async {
    final Result<TagOutcome> result = await _model.delete(entry.tag);
    if (!mounted) return;
    _showFailure(result);
    setState(_reload);
  }

  void _showFailure<T>(Result<T> result) {
    final AppFailure? failure = result.failureOrNull;
    if (failure == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message)),
    );
  }
}
