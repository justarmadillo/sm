/// Outcome returned by a screen opened from the study queue.
library;

/// What a study screen did before it closed.
enum StudyRouteResult {
  /// A repetition committed: the element was answered or read to a
  /// conclusion, and its schedule advanced.
  committed,

  /// A terminal command ran, but it was not a repetition — Later Today, or a
  /// dismissal. The session should move on to the next element without
  /// counting anything as completed.
  moved,

  /// The user left without changing the element.
  canceled;

  /// Whether the study session should advance to the next element.
  bool get advancesSession => this != StudyRouteResult.canceled;

  /// Whether this counts toward "completed this session".
  bool get isRepetition => this == StudyRouteResult.committed;
}
