/// Read-only image rendering with the masks appropriate to one review side.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Displays one occlusion image at the same fitted size used by the Reader.
class OcclusionView extends StatelessWidget {
  const OcclusionView({
    required this.imageProvider,
    required this.occlusion,
    required this.isAnswerRevealed,
    this.shouldRevealAllOcclusions = false,
    super.key,
  });

  final ImageProvider imageProvider;
  final CardOcclusion occlusion;
  final bool isAnswerRevealed;
  final bool shouldRevealAllOcclusions;

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
              for (final region
                  in shouldRevealAllOcclusions
                      ? const <OcclusionRegion>[]
                      : occlusion.coveredRegions(
                          isAnswerRevealed: isAnswerRevealed,
                        ))
                Positioned(
                  key: ValueKey<String>('occlusion-mask-${region.id}'),
                  left: region.left * size.width,
                  top: region.top * size.height,
                  width: region.width * size.width,
                  height: region.height * size.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: region.id == occlusion.activeRegionId
                          ? AppColors.danger
                          : AppColors.mask,
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
