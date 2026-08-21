/// Runs the release-scale deterministic scheduler simulation gate.
///
/// The default policy is the transparent capacity-ledger reference fixture.
/// Adapt the production scheduler through `SchedulerSimulationPolicy` before
/// using this command as the release gate for a production policy change.
library;

import 'dart:convert';
import 'dart:io';

import 'package:incremental_reader/src/domain/scheduling/scheduler_simulation.dart';

void main(List<String> arguments) {
  final String seed =
      _option(arguments, '--seed') ?? 'incremental-reader-scheduler-gate-v1';
  final SchedulerSimulationConfig config = SchedulerSimulationConfig(
    seed: seed,
  );
  final SchedulerSimulationGateReport report =
      const SeededSchedulerSimulationGate().run(
        policy: const CapacityAwareSimulationReferencePolicy(),
        config: config,
      );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  if (!report.accepted) exitCode = 1;
}

String? _option(List<String> arguments, String name) {
  for (var index = 0; index < arguments.length; index++) {
    if (arguments[index] != name) continue;
    if (index + 1 >= arguments.length ||
        arguments[index + 1].startsWith('--')) {
      throw ArgumentError('$name requires a value');
    }
    return arguments[index + 1];
  }
  return null;
}
