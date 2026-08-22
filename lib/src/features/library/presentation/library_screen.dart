/// The Library: every source, split by whether it is due today.
///
/// Not a deck list. A source is a scheduled learning object with a position, so
/// each row says both how far it has been processed and when it comes back.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/toast.dart';
import '../../../application/ports/repositories.dart';
import '../../../application/priority/priority_query.dart';
import '../../../domain/content/source.dart';
import '../../../domain/scheduling/element.dart';
import '../../../domain/scheduling/study_day.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../../priority/presentation/priority_browser_screen.dart';
import '../../priority/presentation/priority_dialog.dart';
import '../../priority/presentation/priority_view_model.dart';
import '../../queue/presentation/queue_screen.dart';
import '../../queue/presentation/queue_view_model.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/presentation/reader_view_model.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'import_sheet.dart';
import 'library_view_model.dart';

/// The application's home screen.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryViewModelProvider);
    final queueCount =
        ref.watch(queueViewModelProvider).valueOrNull?.entries.length ?? 0;

    ref.listen<AsyncValue<LibraryUiState>>(libraryViewModelProvider, (
      AsyncValue<LibraryUiState>? previous,
      AsyncValue<LibraryUiState> next,
    ) {
      final message = next.valueOrNull?.message;
      if (message == null) return;
      showToast(context, message.text, isError: message.isError);
      ref.read(libraryViewModelProvider.notifier).clearMessage();
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        kSearchShortcut: () => openSearch(context, ref),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Library'),
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () async {
                  ref.invalidate(queueViewModelProvider);
                  await openStudyQueue(context, ref);
                  await ref.read(libraryViewModelProvider.notifier).refresh();
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(queueCount == 0 ? 'Study' : 'Study $queueCount'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _openImport(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Import markdown'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Search (Ctrl+F)',
                onPressed: () => openSearch(context, ref),
                icon: const Icon(Icons.search, size: 19),
              ),
              IconButton(
                tooltip: 'Priority queue',
                onPressed: () async {
                  await openPriorityBrowser(context, ref);
                  await ref.read(libraryViewModelProvider.notifier).refresh();
                },
                icon: const Icon(Icons.low_priority, size: 19),
              ),
              IconButton(
                tooltip: 'Diagnostics',
                onPressed: () => openDiagnostics(context, ref),
                icon: const Icon(Icons.insights_outlined, size: 19),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () async {
                  await openSettings(context, ref);
                  await ref.read(libraryViewModelProvider.notifier).refresh();
                },
                icon: const Icon(Icons.settings_outlined, size: 19),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => _ErrorBody(error: error),
            data: (LibraryUiState data) => data.entries.isEmpty
                ? _EmptyBody(onImport: () => _openImport(context, ref))
                : _LibraryBody(state: data),
          ),
        ),
      ),
    );
  }

  Future<void> _openImport(BuildContext context, WidgetRef ref) async {
    final request = await showImportSheet(context);
    if (request == null) return;
    final sourceId = await ref
        .read(libraryViewModelProvider.notifier)
        .importMarkdown(
          title: request.title,
          markdown: request.markdown,
          pace: request.pace,
        );
    if (sourceId != null && context.mounted) {
      ref.invalidate(queueViewModelProvider);
      await openReader(
        context,
        ref,
        sourceId: sourceId,
        mode: ReaderMode.scheduled,
      );
    }
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({required this.state});

  final LibraryUiState state;

  @override
  Widget build(BuildContext context) {
    final due = state.dueToday;
    final later = state.later;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
          children: <Widget>[
            _SectionHeading(
              title: 'Due today',
              count: due.length,
              subtitle: state.today.toString(),
            ),
            if (due.isEmpty)
              const _Hint('Nothing scheduled for today.')
            else
              for (final entry in due)
                _SourceTile(
                  entry: entry,
                  today: state.today,
                  dueDay: state.dueDayOf(entry),
                  isDue: true,
                ),
            const SizedBox(height: 28),
            _SectionHeading(title: 'Everything else', count: later.length),
            for (final entry in later)
              _SourceTile(
                entry: entry,
                today: state.today,
                dueDay: state.dueDayOf(entry),
                isDue: false,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.count,
    this.subtitle,
  });

  final String title;
  final int count;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const Spacer(),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    ),
  );
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({
    required this.entry,
    required this.today,
    required this.dueDay,
    required this.isDue,
  });

  final LibraryEntry entry;
  final StudyDay today;

  /// Effective due, adjustments included.
  final StudyDay dueDay;
  final bool isDue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = entry.source;
    final schedule = entry.schedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openReader(
          context,
          ref,
          sourceId: source.id,
          // Opening from the Library is browsing until the user says
          // otherwise: looking something up must not become progress.
          mode: isDue ? ReaderMode.scheduled : ReaderMode.browse,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleFor(entry, today, dueDay),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _LifecycleChip(lifecycle: schedule.lifecycle, isDue: isDue),
              const SizedBox(width: 8),
              _PriorityCell(entry: entry),
              _SourceMenu(entry: entry),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleFor(LibraryEntry entry, StudyDay today, StudyDay dueDay) {
    final parts = <String>['${entry.source.wordCount} words'];
    if (entry.extractCount > 0) {
      parts.add(
        '${entry.extractCount} extract'
        '${entry.extractCount == 1 ? '' : 's'}',
      );
    }
    parts.add(
      entry.source.resume.marker == null ? 'not started' : 'position kept',
    );
    if (entry.schedule.lifecycle.isSchedulable) {
      final days = today.daysUntil(dueDay);
      parts.add(switch (days) {
        <= 0 => 'due now',
        1 => 'due tomorrow',
        _ => 'due in $days days',
      });
    }
    return parts.join(' · ');
  }
}

/// The element's relative priority, and a way to change it.
class _PriorityCell extends ConsumerWidget {
  const _PriorityCell({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PriorityBrowserState> browser = ref.watch(
      priorityBrowserProvider,
    );
    final ElementRef elementRef = ElementRef(
      id: entry.source.id,
      type: ElementType.source,
    );
    // Percentiles are derived from the live order, so they come from the same
    // projection the browser uses rather than being stored on the row.
    final double? percent = browser.valueOrNull?.entries
        .where((PriorityEntry e) => e.ref == elementRef)
        .map((PriorityEntry e) => e.percent)
        .firstOrNull;

    return PriorityBadge(
      percent: percent ?? 50,
      onTap: () async {
        final bool changed = await showPriorityDialog(
          context,
          ref,
          elementRef: elementRef,
        );
        if (changed) {
          ref.invalidate(priorityBrowserProvider);
          await ref.read(libraryViewModelProvider.notifier).refresh();
        }
      },
    );
  }
}

class _LifecycleChip extends StatelessWidget {
  const _LifecycleChip({required this.lifecycle, required this.isDue});

  final ElementLifecycle lifecycle;
  final bool isDue;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (lifecycle) {
      ElementLifecycle.active when isDue => ('Due', AppColors.accent),
      ElementLifecycle.active => ('Scheduled', AppColors.muted),
      ElementLifecycle.finished => ('Finished', AppColors.muted),
      ElementLifecycle.dismissed => ('Dismissed', AppColors.muted),
      ElementLifecycle.suspended => ('Suspended', AppColors.softMarker),
      ElementLifecycle.deleted => ('Deleted', AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _SourceMenu extends ConsumerWidget {
  const _SourceMenu({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.read(libraryViewModelProvider.notifier);
    final elementRef = ElementRef(
      id: entry.source.id,
      type: ElementType.source,
    );

    return PopupMenuButton<String>(
      tooltip: 'Source actions',
      icon: const Icon(Icons.more_horiz, size: 18, color: AppColors.muted),
      onSelected: (String action) async {
        switch (action) {
          case 'browse':
            await openReader(
              context,
              ref,
              sourceId: entry.source.id,
              mode: ReaderMode.browse,
            );
          case 'rename':
            final title = await _promptForTitle(context, entry.source.title);
            if (title != null) await model.rename(entry.source.id, title);
          case 'reactivate':
            await model.reactivate(elementRef);
          case 'dismiss':
            await model.dismiss(elementRef);
          case 'delete':
            if (await _confirmDelete(context, entry.source.title)) {
              await model.deleteSource(entry.source.id);
            }
          default:
            final pace = ReadingPace.values.firstWhere(
              (ReadingPace p) => 'pace:${p.name}' == action,
            );
            await model.setPace(entry.source.id, pace);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'browse',
          child: Text('Open in browse mode'),
        ),
        const PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
        const PopupMenuDivider(),
        for (final pace in ReadingPace.values)
          PopupMenuItem<String>(
            value: 'pace:${pace.name}',
            child: Row(
              children: <Widget>[
                Icon(
                  entry.source.pace == pace
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text('${pace.name} pace'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        if (entry.schedule.lifecycle.isSchedulable)
          const PopupMenuItem<String>(
            value: 'dismiss',
            child: Text('Dismiss (keep content)'),
          )
        else
          const PopupMenuItem<String>(
            value: 'reactivate',
            child: Text('Return to queue'),
          ),
        const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<String?> _promptForTitle(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename source'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (String value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Delete source?'),
          content: Text(
            'This removes "$title" from learning while retaining its content, '
            'extracts, and cards. You can restore it later.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Nothing imported yet',
          style: TextStyle(fontSize: 16, color: AppColors.text),
        ),
        const SizedBox(height: 6),
        const Text(
          'Paste a chapter or an article to start reading it incrementally.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onImport, child: const Text('Import markdown')),
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.muted),
    ),
  );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Could not load the library.\n$error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
    ),
  );
}
