@TestOn('vm')
library;

import 'dart:io';

import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/models/watch_history_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// The schema exactly as older builds of the app created it, so the tests can
/// prove that an existing user database keeps working.
const String _legacySchema = '''
  CREATE TABLE IF NOT EXISTS watch_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tmdb_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('movie', 'tv')),
    poster_path TEXT,
    watched_at INTEGER NOT NULL,
    season_number INTEGER,
    episode_number INTEGER,
    episode_title TEXT,
    user_rating REAL,
    notes TEXT,
    UNIQUE(tmdb_id, type, season_number, episode_number)
  )
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late String databasePath;

  setUp(() {
    documents = Directory.systemTemp.createTempSync('mirarr_watch_history');
    databasePath = p.join(documents.path, 'watch_history.db');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => documents.path,
    );
  });

  tearDown(() async {
    await WatchHistoryDatabase().close();
    documents.deleteSync(recursive: true);
  });

  test('creates the schema and stamps a version on a fresh database', () async {
    final db = WatchHistoryDatabase();
    await db.addMovieToHistory(tmdbId: 1, title: 'Dune');

    expect(await db.getWatchedMovies(), hasLength(1));

    await db.close();
    expect(_userVersion(databasePath), 1);
  });

  test('adopts a database written by an older build without losing rows',
      () async {
    final legacy = sqlite3.open(databasePath);
    legacy.execute(_legacySchema);
    legacy.execute(
      'INSERT INTO watch_history (tmdb_id, title, type, watched_at) '
      "VALUES (603, 'The Matrix', 'movie', 946684800000)",
    );
    expect(legacy.userVersion, 0);
    legacy.dispose();

    final db = WatchHistoryDatabase();
    final movies = await db.getWatchedMovies();

    expect(movies, hasLength(1));
    expect(movies.single.title, 'The Matrix');
    expect(await db.isWatched(603, 'movie'), isTrue);

    await db.close();
    expect(_userVersion(databasePath), 1);
  });

  test('round trips inserts, updates, deletes and stats', () async {
    final db = WatchHistoryDatabase();

    final movieId = await db.addMovieToHistory(tmdbId: 1, title: 'Dune');
    await db.addShowToHistory(
      tmdbId: 2,
      title: 'Severance',
      seasonNumber: 1,
      episodeNumber: 3,
    );

    expect(await db.getWatchStats(), {'movies': 1, 'shows': 1});
    expect(await db.isWatched(2, 'tv', seasonNumber: 1, episodeNumber: 3),
        isTrue);
    expect(await db.isWatched(2, 'tv', seasonNumber: 1, episodeNumber: 4),
        isFalse);

    // Re-adding the same movie updates the existing row instead of duplicating.
    await db.addMovieToHistory(tmdbId: 1, title: 'Dune: Part Two');
    final movies = await db.getWatchedMovies();
    expect(movies, hasLength(1));
    expect(movies.single.title, 'Dune: Part Two');

    await db.deleteWatchHistoryItem(movieId);
    expect(await db.getWatchedMovies(), isEmpty);
    expect(await db.getAllWatchHistory(), hasLength(1));
  });

  test('rolls the whole import back when one item is rejected', () async {
    final db = WatchHistoryDatabase();
    await db.addMovieToHistory(tmdbId: 1, title: 'Dune');

    await expectLater(
      db.importWatchHistory([
        WatchHistoryItem(
            tmdbId: 2, title: 'Arrival', type: 'movie', watchedAt: DateTime(2024)),
        WatchHistoryItem(
            tmdbId: 3, title: 'Broken', type: 'game', watchedAt: DateTime(2024)),
      ]),
      throwsA(isA<Exception>()),
    );

    expect(await db.getAllWatchHistory(), hasLength(1));
  });

  test('close releases the file so a backup can be restored over it', () async {
    final db = WatchHistoryDatabase();
    await db.addMovieToHistory(tmdbId: 1, title: 'Dune');
    await db.close();

    final backup = sqlite3.open(p.join(documents.path, 'backup.db'));
    backup.execute(_legacySchema);
    backup.execute(
      'INSERT INTO watch_history (tmdb_id, title, type, watched_at) '
      "VALUES (27205, 'Inception', 'movie', 946684800000)",
    );
    backup.dispose();

    // Mirrors the restore flow in the settings screen.
    expect(documents.listSync().map((entry) => p.basename(entry.path)),
        unorderedEquals(['watch_history.db', 'backup.db']));
    File(p.join(documents.path, 'backup.db')).copySync(databasePath);

    final movies = await WatchHistoryDatabase().getWatchedMovies();
    expect(movies.single.title, 'Inception');
  });

  test('recovers after the database is closed mid-session', () async {
    final db = WatchHistoryDatabase();
    await db.addMovieToHistory(tmdbId: 1, title: 'Dune');
    await db.close();

    expect(await db.getWatchedMovies(), hasLength(1));
  });
}

int _userVersion(String path) {
  final db = sqlite3.open(path);
  try {
    return db.userVersion;
  } finally {
    db.dispose();
  }
}
