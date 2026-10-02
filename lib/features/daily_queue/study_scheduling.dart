/// How a study screen treats the schedule of the element it shows.
///
/// The daily queue and a custom deck open the same review, reader, extract,
/// and video screens. This is the one value that tells those screens whether
/// finishing the element moves its schedule.
library;

/// Which scheduling a study screen applies when its element is finished.
enum StudyScheduling {
  /// The daily queue: Done and every grade advance the schedule, and a card
  /// that is not due yet is refused, because then the queue is stale.
  scheduled,

  /// A custom deck that reschedules: a card may be graded before it is due,
  /// and FSRS reschedules it from the time that actually elapsed — the way an
  /// Anki filtered deck does. Topics behave as [scheduled].
  earlyReview,

  /// A cram sitting: the element is logged as practiced and its schedule does
  /// not move. Always used for cram-only elements.
  practice;

  bool get isPractice => this == practice;

  bool get isEarlyReviewAllowed => this == earlyReview;
}
