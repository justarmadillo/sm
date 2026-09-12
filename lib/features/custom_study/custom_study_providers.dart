/// Builds the read-only objects used by the custom study screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_providers.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';

/// The inherited-tag population query, constructed once per provider scope.
final Provider<CustomStudyQuery> customStudyQueryProvider =
    Provider<CustomStudyQuery>(
      (Ref ref) => CustomStudyQuery(
        tree: ref.watch(browserTreeQueryProvider),
        learning: ref.watch(learningRepositoryProvider),
      ),
    );
