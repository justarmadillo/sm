/// The v15 to v16 upgrade: video becomes a fourth element type.
///
/// The risk this test exists for is not the two new tables — a `CREATE TABLE`
/// either works or throws. It is the five CHECK constraints that spelled out
/// which element types exist. SQLite validates those on write, so a collection
/// that skipped the widening would open, look healthy, and then refuse every
/// video the user tried to save.
///
/// So the seed does not merely set `user_version`: it rebuilds those five
/// tables with the constraints v15 really had, and asserts the narrow version
/// rejects a video before the upgrade runs. Without that, the test would pass
/// against a database that was already wide and prove nothing.
library;

import 'dart:io';

import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

/// The exact constraint text v16 writes, and what v15 had in its place.
///
/// Keyed by table. Read out of `sqlite_master` and swapped textually, because
/// hand-copying five whole `CREATE TABLE` statements into a test is how a
/// seed silently stops resembling the schema it claims to reproduce.
const Map<String, (String, String)> _narrowings = <String, (String, String)>{
  'element_schedules': (
    'CHECK("element_type" BETWEEN 0 AND 3)',
    'CHECK("element_type" BETWEEN 0 AND 2)',
  ),
  'search_documents': (
    'CHECK("element_type" BETWEEN 0 AND 3)',
    'CHECK("element_type" BETWEEN 0 AND 2)',
  ),
  'revlog_entries': (
    'CHECK("element_type" BETWEEN 0 AND 3)',
    'CHECK("element_type" BETWEEN 0 AND 2)',
  ),
  'topic_states': (
    'CHECK("element_type" IN (0, 1, 3))',
    'CHECK("element_type" BETWEEN 0 AND 1)',
  ),
  'cards': (
    'CHECK("parent_element_type" IN (0, 1, 3))',
    'CHECK("parent_element_type" BETWEEN 0 AND 1)',
  ),
};

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-v16-');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> openFileDatabase() async {
    final AppDatabase database = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  Future<String> tableSql(AppDatabase database, String table) async {
    final rows = await database
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' "
          "AND name = '$table'",
        )
        .get();
    return rows.single.read<String>('sql');
  }

  Future<int> countRows(AppDatabase database, String table) async {
    final rows = await database
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .get();
    return rows.single.read<int>('n');
  }

  /// Puts the collection back at v15: the video tables gone, the five element
  /// type constraints narrowed, and one row of real data in each.
  Future<void> seedV15(AppDatabase database) async {
    await database.customStatement('PRAGMA foreign_keys = OFF');

    await database.customStatement('DROP TABLE IF EXISTS video_elements');
    await database.customStatement('DROP TABLE IF EXISTS videos');

    for (final MapEntry<String, (String, String)> entry
        in _narrowings.entries) {
      final String table = entry.key;
      final (String wide, String narrow) = entry.value;
      final String sql = await tableSql(database, table);
      expect(
        sql,
        contains(wide),
        reason:
            'the v16 shape of $table no longer contains the text this seed '
            'narrows, so the seed would reproduce a v16 table and the test '
            'would prove nothing',
      );
      await database.customStatement('DROP TABLE $table');
      await database.customStatement(sql.replaceFirst(wide, narrow));
    }

    await database.customStatement(
      'INSERT INTO element_schedules (element_id, element_type, priority_key, '
      'lifecycle, due_day, original_due_day, root_id, zone_id) '
      "VALUES ('src-1', 0, 'a', 0, 100, 100, 'src-1', 'UTC')",
    );
    await database.customStatement(
      'INSERT INTO element_schedules (element_id, element_type, priority_key, '
      'lifecycle, due_day, original_due_day, root_id, zone_id) '
      "VALUES ('ext-1', 1, 'b', 0, 101, 101, 'src-1', 'UTC')",
    );
    await database.customStatement(
      'INSERT INTO topic_states (element_id, element_type, status) '
      "VALUES ('src-1', 0, 1)",
    );
    await database.customStatement(
      'INSERT INTO cards (id, parent_element_id, parent_element_type, type, '
      'front, back, created_at_utc) '
      "VALUES ('card-1', 'ext-1', 1, 0, 'question', 'answer', 1000)",
    );
    await database.customStatement(
      'INSERT INTO revlog_entries (id, operation_id, element_id, element_type, '
      'event_type, at_utc) '
      "VALUES ('log-1', 'op-1', 'src-1', 0, 1, 1000)",
    );
    await database.customStatement(
      'INSERT INTO search_documents (element_id, element_type, title, body, '
      'source_id, updated_at_utc) '
      "VALUES ('src-1', 0, 'Mitral valve', 'chordae rupture', 'src-1', 1000)",
    );

    await database.customStatement('PRAGMA user_version = 15');
  }

  /// Whether [statement] was refused by the database.
  Future<bool> isRejected(AppDatabase database, String statement) async {
    try {
      await database.customStatement(statement);
      return false;
    } on Object {
      return true;
    }
  }

  test('the seed really is narrower than v16', () async {
    final AppDatabase seeded = await openFileDatabase();
    addTearDown(seeded.close);
    await seedV15(seeded);

    expect(
      await isRejected(
        seeded,
        'INSERT INTO element_schedules (element_id, element_type, '
        'priority_key, lifecycle, due_day, original_due_day, zone_id) '
        "VALUES ('vid-0', 3, 'c', 0, 100, 100, 'UTC')",
      ),
      isTrue,
      reason: 'a v15 collection must refuse element type 3',
    );
  });

  test('every seeded row survives the upgrade', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV15(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    expect(await countRows(upgraded, 'element_schedules'), 2);
    expect(await countRows(upgraded, 'topic_states'), 1);
    expect(await countRows(upgraded, 'cards'), 1);
    expect(await countRows(upgraded, 'revlog_entries'), 1);
    expect(await countRows(upgraded, 'search_documents'), 1);

    final rows = await upgraded
        .customSelect(
          'SELECT parent_element_id, parent_element_type, front FROM cards '
          "WHERE id = 'card-1'",
        )
        .get();
    expect(rows.single.read<String>('parent_element_id'), 'ext-1');
    expect(rows.single.read<int>('parent_element_type'), 1);
    expect(rows.single.read<String>('front'), 'question');
  });

  test('a whole video and a clip are storable after the upgrade', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV15(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    await upgraded.customStatement(
      'INSERT INTO videos (id, url, platform, duration_seconds, added_at_utc) '
      "VALUES ('v-1', 'https://youtu.be/abc', 0, 3600, 1000)",
    );
    await upgraded.customStatement(
      'INSERT INTO video_elements (id, video_id, title, start_seconds, '
      'end_seconds, created_at_utc) '
      "VALUES ('vid-1', 'v-1', 'A talk', 0, 3600, 1000)",
    );
    await upgraded.customStatement(
      'INSERT INTO video_elements (id, video_id, parent_video_element_id, '
      'note, start_seconds, end_seconds, created_at_utc) '
      "VALUES ('clip-1', 'v-1', 'vid-1', 'the point', 252, 450, 1000)",
    );

    // Every one of the five widened tables, exercised with the new type.
    await upgraded.customStatement(
      'INSERT INTO element_schedules (element_id, element_type, priority_key, '
      'lifecycle, due_day, original_due_day, root_id, zone_id) '
      "VALUES ('vid-1', 3, 'c', 0, 100, 100, 'vid-1', 'UTC')",
    );
    await upgraded.customStatement(
      'INSERT INTO topic_states (element_id, element_type, status) '
      "VALUES ('vid-1', 3, 0)",
    );
    await upgraded.customStatement(
      'INSERT INTO search_documents (element_id, element_type, title, body, '
      'updated_at_utc) VALUES ('
      "'clip-1', 3, 'A talk', 'the point', 1000)",
    );
    await upgraded.customStatement(
      'INSERT INTO revlog_entries (id, operation_id, element_id, element_type, '
      'event_type, at_utc) '
      "VALUES ('log-2', 'op-2', 'vid-1', 3, 1, 2000)",
    );
    await upgraded.customStatement(
      'INSERT INTO cards (id, parent_element_id, parent_element_type, type, '
      'front, back, created_at_utc) '
      "VALUES ('card-2', 'clip-1', 3, 0, 'from a clip', 'answer', 2000)",
    );

    expect(await countRows(upgraded, 'video_elements'), 2);
    expect(await countRows(upgraded, 'element_schedules'), 3);
  });

  test('the video range constraints are enforced after the upgrade', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV15(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    await upgraded.customStatement(
      'INSERT INTO videos (id, url, platform, added_at_utc) '
      "VALUES ('v-1', 'https://youtu.be/abc', 0, 1000)",
    );

    expect(
      await isRejected(
        upgraded,
        'INSERT INTO video_elements (id, video_id, title, start_seconds, '
        'end_seconds, created_at_utc) '
        "VALUES ('bad-1', 'v-1', 'Empty', 300, 300, 1000)",
      ),
      isTrue,
      reason: 'a range that ends where it starts holds nothing',
    );
    expect(
      await isRejected(
        upgraded,
        'INSERT INTO video_elements (id, video_id, start_seconds, '
        'end_seconds, created_at_utc) '
        "VALUES ('bad-2', 'v-1', 0, 3600, 1000)",
      ),
      isTrue,
      reason: 'a whole video with no title is unfindable in the tree',
    );
    expect(
      await isRejected(
        upgraded,
        'INSERT INTO video_elements (id, video_id, title, start_seconds, '
        'end_seconds, resume_seconds, created_at_utc) '
        "VALUES ('bad-3', 'v-1', 'Outside', 100, 200, 900)",
      ),
      isTrue,
      reason: 'a resume position outside its own range is not a position',
    );
  });

  // The rebuild drops search_documents and recreates it, which takes the FTS
  // triggers with it and leaves the index addressing rowids that no longer
  // mean what they did. Search returning the wrong element is silent.
  test('full-text search still finds the seeded row afterwards', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV15(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    final matches = await upgraded
        .customSelect(
          'SELECT d.element_id AS element_id FROM $kSearchIndexTable i '
          'JOIN search_documents d ON d.rowid = i.rowid '
          "WHERE $kSearchIndexTable MATCH 'chordae'",
        )
        .get();
    expect(matches, hasLength(1));
    expect(matches.single.read<String>('element_id'), 'src-1');
  });

  test('a video document is searchable once it is written', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV15(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    await upgraded.customStatement(
      'INSERT INTO search_documents (element_id, element_type, title, body, '
      "updated_at_utc) VALUES ('clip-1', 3, 'A talk', 'phacoemulsification', "
      '2000)',
    );

    final matches = await upgraded
        .customSelect(
          'SELECT d.element_id AS element_id, d.element_type AS element_type '
          'FROM $kSearchIndexTable i '
          'JOIN search_documents d ON d.rowid = i.rowid '
          "WHERE $kSearchIndexTable MATCH 'phacoemulsification'",
        )
        .get();
    expect(matches, hasLength(1));
    expect(matches.single.read<String>('element_id'), 'clip-1');
    expect(matches.single.read<int>('element_type'), 3);
  });

  test('the upgrade is safe to run twice', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV15(seeded);
    await seeded.close();

    final AppDatabase once = await openFileDatabase();
    await once.close();

    final AppDatabase twice = await openFileDatabase();
    addTearDown(twice.close);
    expect(await countRows(twice, 'element_schedules'), 2);
  });
}
