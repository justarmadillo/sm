/// Screen for drawing masks and creating image-occlusion cards.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/occlusion/occlusion_commands.dart';
import 'package:incremental_reader/features/occlusion/occlusion_providers.dart';
import 'package:incremental_reader/features/occlusion/widgets/occlusion_canvas.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/reader/reader_image_input.dart';
import 'package:incremental_reader/features/reader/reader_providers.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

enum _OcclusionImageSource { files, clipboard }

/// Lets touch devices choose the same image from storage or the clipboard.
Future<SourceImageImport?> chooseOcclusionImage(
  BuildContext context,
  WidgetRef ref,
) async {
  final source = await showModalBottomSheet<_OcclusionImageSource>(
    context: context,
    builder: (BuildContext context) => SafeArea(
      child: Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Choose image'),
            onTap: () => Navigator.of(context).pop(_OcclusionImageSource.files),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste_outlined),
            title: const Text('Paste image'),
            onTap: () =>
                Navigator.of(context).pop(_OcclusionImageSource.clipboard),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  try {
    final input = ref.read(readerImageInputProvider);
    final images = source == _OcclusionImageSource.files
        ? await input.chooseImages()
        : await input.readClipboardImage();
    return images.firstOrNull;
  } on ReaderImageInputException catch (failure) {
    if (context.mounted) showToast(context, failure.message, isError: true);
    return failure.validImages.firstOrNull;
  }
}

/// Opens the editor and returns the cards it created.
Future<List<ElementRef>?> openOcclusionScreen(
  BuildContext context,
  WidgetRef ref, {
  required SourceImageImport image,
  CardParent? parent,
}) => Navigator.of(context).push<List<ElementRef>>(
  MaterialPageRoute<List<ElementRef>>(
    builder: (_) => OcclusionScreen(image: image, parent: parent),
  ),
);

/// Reopens an existing occlusion in the same editor used to create it.
Future<void> openOcclusionCardEditor(
  BuildContext context,
  WidgetRef ref, {
  required String cardId,
}) async {
  final card = await ref.read(contentRepositoryProvider).findCard(cardId);
  final occlusion = await ref
      .read(occlusionRepositoryProvider)
      .findCardOcclusion(cardId);
  if (card == null || occlusion == null || !context.mounted) {
    if (context.mounted) {
      showToast(
        context,
        'This image occlusion is no longer available.',
        isError: true,
      );
    }
    return;
  }
  final bytes = await ref
      .read(sourceAssetFileStoreProvider)
      .fileForSha256(occlusion.imageSha256)
      .readAsBytes();
  if (!context.mounted) return;
  await Navigator.of(context).push<List<ElementRef>>(
    MaterialPageRoute<List<ElementRef>>(
      builder: (_) => OcclusionScreen(
        image: SourceImageImport(
          bytes: bytes,
          altText: 'Image',
          sha256: occlusion.imageSha256,
          mime: occlusion.imageMime,
          widthPx: occlusion.imageWidthPx,
          heightPx: occlusion.imageHeightPx,
        ),
        parent: card.parent,
        card: card,
        occlusion: occlusion,
      ),
    ),
  );
}

class OcclusionScreen extends ConsumerStatefulWidget {
  const OcclusionScreen({
    required this.image,
    required this.parent,
    this.card,
    this.occlusion,
    super.key,
  }) : assert((card == null) == (occlusion == null));

  final SourceImageImport image;
  final CardParent? parent;
  final Card? card;
  final CardOcclusion? occlusion;

  @override
  ConsumerState<OcclusionScreen> createState() => _OcclusionScreenState();
}

class _OcclusionScreenState extends ConsumerState<OcclusionScreen> {
  final TextEditingController _header = TextEditingController();
  final TextEditingController _extra = TextEditingController();
  late List<OcclusionRegion> _regions;
  late OcclusionMode _mode;
  bool _isBusy = false;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    _header.text = widget.card?.front ?? '';
    _extra.text = widget.card?.extra ?? '';
    _regions = widget.occlusion?.regions ?? const <OcclusionRegion>[];
    _mode = widget.occlusion?.mode ?? OcclusionMode.hideAllGuessOne;
  }

  @override
  void dispose() {
    _header.dispose();
    _extra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isEditing ? 'Edit image occlusion' : 'Image occlusion'),
      actions: <Widget>[
        FilledButton(
          onPressed: _isBusy || _regions.isEmpty ? null : _save,
          child: Text(
            _isBusy
                ? (_isEditing ? 'Saving…' : 'Creating…')
                : (_isEditing ? 'Save' : 'Create cards'),
          ),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: Column(
      children: <Widget>[
        _controls(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: OcclusionCanvas(
              imageProvider: MemoryImage(widget.image.bytes),
              imageWidthPx: widget.image.widthPx,
              imageHeightPx: widget.image.heightPx,
              regions: _regions,
              newRegionId: () => ref.read(idGeneratorProvider).newId(),
              onChanged: (List<OcclusionRegion> regions) =>
                  setState(() => _regions = regions),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _controls() => Material(
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 240,
            child: TextField(
              controller: _header,
              decoration: const InputDecoration(labelText: 'Header (optional)'),
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _extra,
              decoration: const InputDecoration(labelText: 'Extra (optional)'),
            ),
          ),
          DropdownButton<OcclusionMode>(
            value: _mode,
            onChanged: _isBusy
                ? null
                : (OcclusionMode? mode) {
                    if (mode != null) setState(() => _mode = mode);
                  },
            items: const <DropdownMenuItem<OcclusionMode>>[
              DropdownMenuItem(
                value: OcclusionMode.hideAllGuessOne,
                child: Text('Hide All, Guess One'),
              ),
              DropdownMenuItem(
                value: OcclusionMode.hideOneGuessOne,
                child: Text('Hide One, Guess One'),
              ),
              DropdownMenuItem(
                value: OcclusionMode.hideAllGuessAll,
                child: Text('Hide All, Guess All'),
              ),
            ],
          ),
          Text('${_regions.length} mask${_regions.length == 1 ? '' : 's'}'),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    setState(() => _isBusy = true);
    if (_isEditing) {
      final result = await ref
          .read(occlusionCommandRunnerProvider)
          .edit(
            EditOcclusionCard(
              OperationId(ref.read(idGeneratorProvider).newId()),
              cardId: widget.card!.id,
              regions: _regions,
              mode: _mode,
              header: _header.text,
              extra: _extra.text,
            ),
          );
      if (!mounted) return;
      if (result.isErr) {
        setState(() => _isBusy = false);
        showToast(context, result.failureOrNull!.message, isError: true);
        return;
      }
      Navigator.of(context).pop(const <ElementRef>[]);
      return;
    }
    final result = await ref
        .read(occlusionCommandRunnerProvider)
        .create(
          CreateOcclusionCards(
            OperationId(ref.read(idGeneratorProvider).newId()),
            parent: widget.parent,
            image: widget.image,
            regions: _regions,
            mode: _mode,
            header: _header.text,
            extra: _extra.text,
          ),
        );
    if (!mounted) return;
    if (result.isErr) {
      setState(() => _isBusy = false);
      showToast(context, result.failureOrNull!.message, isError: true);
      return;
    }
    Navigator.of(context).pop(<ElementRef>[
      for (final card in result.unwrap())
        ElementRef(id: card.id, type: ElementType.card),
    ]);
  }
}
