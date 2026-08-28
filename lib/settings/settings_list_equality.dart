/// Comparing the list-shaped settings values by content instead of identity.
///
/// Two settings objects built from the same stored rows are different objects,
/// so `==` on the lists inside them would always be false and every read would
/// look like a change.
library;

bool intListsAreEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool nullableIntListsAreEqual(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  return intListsAreEqual(a, b);
}
