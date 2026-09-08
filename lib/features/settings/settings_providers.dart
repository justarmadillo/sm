/// Builds the platform and app-lifecycle promises used only by Settings.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/collection_replacement.dart';
import 'package:incremental_reader/features/settings/collection_file_dialogs.dart';

/// Dialog gateway used by Settings and overridden by widget tests.
final Provider<CollectionFileDialogs> collectionFileDialogsProvider =
    Provider<CollectionFileDialogs>((Ref ref) => const CollectionFileDialogs());

/// Collection replacement lifecycle supplied by the application root.
final Provider<CollectionReplacement> collectionReplacementProvider =
    Provider<CollectionReplacement>(
      (Ref ref) =>
          throw StateError('collectionReplacementProvider must be overridden'),
    );
