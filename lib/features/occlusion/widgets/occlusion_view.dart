/// Read-only image rendering with the masks appropriate to one review side.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';

/// Displays one occlusion image at the same fitted size used by the Reader.
class OcclusionView extends StatelessWidget {
  const OcclusionView({
    required this.imageProvider,
    required this.occlusion,
    required this.isAnswerRevealed,
    super.key,
  });

  final ImageProvider imageProvider;
  final CardOcclusion occlusion;
  final bool isAnswerRevealed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final size = fittedReaderImageSize(
        widthPx: occlusion.imageWidthPx,
        heightPx: occlusion.imageHeightPx,
        maxWidth: constraints.maxWidth,
      );
      return Align(
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image(image: imageProvider, fit: BoxFit.fill),
              for (final region in occlusion.coveredRegions(
                isAnswerRevealed: isAnswerRevealed,
              ))
                Positioned(
                  left: region.left * size.width,
                  top: region.top * size.height,
                  width: region.width * size.width,
                  height: region.height * size.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: region.id == occlusion.activeRegionId
                          ? const Color(0xFFD14E3E)
                          : const Color(0xFF242A32),
                      border: region.id == occlusion.activeRegionId
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
