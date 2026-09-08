/// The app-level promise for replacing the currently open collection.
library;

import 'dart:io';

import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';

/// Lets Settings request replacement without owning the database lifecycle.
abstract interface class CollectionReplacement {
  Future<Result<Unit>> replaceWithPackage(
    File packageFile, {
    required OperationId operationId,
  });
}
