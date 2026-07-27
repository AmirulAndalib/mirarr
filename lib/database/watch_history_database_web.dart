import 'package:Mirarr/models/watch_history_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WatchHistoryDatabase {
  static Box? _webBox;
  static List<WatchHistoryItem>? _cachedItems;
  static Map<String, WatchHistoryItem>? _cachedByKey;

  Future<Box> get webBox async {
    if (_webBox != null) return _webBox!;
    _webBox = await Hive.openBox('watch_history_box');
    _rebuildCache(_webBox!);
    return _webBox!;
  }

  void _rebuildCache(Box box) {
    final list = box.values
        .map((val) =>
            WatchHistoryItem.fromMap(Map<String, dynamic>.from(val as Map)))
        .toList();
    list.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    _cachedItems = list;
    _cachedByKey = {
      for (final item in list) _itemKey(item): item,
    };
  }

  void _invalidateCache() {
    _cachedItems = null;
    _cachedByKey = null;
  }

  Future<List<WatchHistoryItem>> _ensureCache() async {
    final box = await webBox;
    if (_cachedItems == null) {
      _rebuildCache(box);
    }
    return _cachedItems!;
  }

  static String _itemKeyFromParts(
    int tmdbId,
    String type,
    int? seasonNumber,
    int? episodeNumber,
  ) =>
      '${type}_${tmdbId}_${seasonNumber}_${episodeNumber}';

  static String _itemKey(WatchHistoryItem item) => _itemKeyFromParts(
        item.tmdbId,
        item.type,
        item.seasonNumber,
        item.episodeNumber,
      );

  Future<int> insertWatchHistoryItem(WatchHistoryItem item) async {
    final box = await webBox;
    await _ensureCache();
    final existing = _cachedByKey![_itemKey(item)];
    if (existing != null) {
      await updateWatchHistoryItem(item);
      return existing.id ?? 0;
    }
    final id = item.id ??
        (box.isEmpty
            ? 1
            : (box.keys.cast<int>().reduce((a, b) => a > b ? a : b) + 1));
    final newItem = item.copyWith(id: id);
    await box.put(newItem.id, newItem.toMap());
    _invalidateCache();
    return newItem.id!;
  }

  Future<void> importWatchHistory(List<WatchHistoryItem> items) async {
    final box = await webBox;

    // 1. Build lookup map of existing items in the box: type_tmdbId_season_episode -> id
    final Map<String, int> existingKeys = {};
    for (var entry in box.toMap().entries) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      final key =
          "${map['type']}_${map['tmdb_id']}_${map['season_number']}_${map['episode_number']}";
      existingKeys[key] = entry.key as int;
    }

    // 2. Perform duplicate checks and construct batch updates
    final Map<int, Map<String, dynamic>> itemsToPut = {};
    int nextId = box.isEmpty
        ? 1
        : (box.keys.cast<int>().reduce((a, b) => a > b ? a : b) + 1);

    for (var item in items) {
      final key =
          "${item.type}_${item.tmdbId}_${item.seasonNumber}_${item.episodeNumber}";
      if (existingKeys.containsKey(key)) {
        final existingId = existingKeys[key]!;
        final updatedItem = item.copyWith(id: existingId);
        itemsToPut[existingId] = updatedItem.toMap();
      } else {
        final newId = nextId++;
        final newItem = item.copyWith(id: newId);
        itemsToPut[newId] = newItem.toMap();
        existingKeys[key] = newId; // Update lookup in case duplicate exists in imported list
      }
    }

    if (itemsToPut.isNotEmpty) {
      await box.putAll(itemsToPut);
      _invalidateCache();
    }
  }

  Future<void> updateWatchHistoryItem(WatchHistoryItem item) async {
    final box = await webBox;
    await _ensureCache();
    final existing = _cachedByKey![_itemKey(item)];
    if (existing?.id == null) return;

    final keyToUpdate = existing!.id!;
    final updatedItem = WatchHistoryItem(
      id: keyToUpdate,
      tmdbId: item.tmdbId,
      title: item.title,
      type: item.type,
      posterPath: item.posterPath,
      watchedAt: item.watchedAt,
      seasonNumber: item.seasonNumber,
      episodeNumber: item.episodeNumber,
      episodeTitle: item.episodeTitle,
      userRating: item.userRating,
      notes: item.notes,
    );
    await box.put(keyToUpdate, updatedItem.toMap());
    _invalidateCache();
  }

  Future<void> deleteWatchHistoryItem(int id) async {
    final box = await webBox;
    await box.delete(id);
    _invalidateCache();
  }

  Future<void> addShowEpisodesBatch(List<WatchHistoryItem> items) async {
    if (items.isEmpty) return;
    await importWatchHistory(items);
  }

  Future<void> deleteWatchHistoryItemsBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    final box = await webBox;
    await box.deleteAll(ids);
    _invalidateCache();
  }

  Future<List<WatchHistoryItem>> getAllWatchHistory() async {
    final list = await _ensureCache();
    return List<WatchHistoryItem>.from(list);
  }

  Future<List<WatchHistoryItem>> getWatchedMovies() async {
    final list = await _ensureCache();
    return list.where((item) => item.type == 'movie').toList();
  }

  Future<List<WatchHistoryItem>> getWatchedShows() async {
    final list = await _ensureCache();
    return list.where((item) => item.type == 'tv').toList();
  }

  Future<List<WatchHistoryItem>> getWatchHistoryByTmdbId(
      int tmdbId, String type) async {
    final list = await _ensureCache();
    return list
        .where((item) => item.tmdbId == tmdbId && item.type == type)
        .toList();
  }

  Future<bool> isWatched(int tmdbId, String type,
      {int? seasonNumber, int? episodeNumber}) async {
    await _ensureCache();
    return _cachedByKey!.containsKey(
        _itemKeyFromParts(tmdbId, type, seasonNumber, episodeNumber));
  }

  Future<List<WatchHistoryItem>> getRecentWatchHistory({int limit = 20}) async {
    final list = await _ensureCache();
    return list.take(limit).toList();
  }

  Future<Map<String, int>> getWatchStats() async {
    final list = await _ensureCache();
    final movieCount = list.where((item) => item.type == 'movie').length;
    final showCount = list.where((item) => item.type == 'tv').length;

    return {
      'movies': movieCount,
      'shows': showCount,
    };
  }

  Future<int> getWatchHistoryCount() async {
    final box = await webBox;
    return box.length;
  }

  Future<void> close() async {
    if (_webBox != null) {
      await _webBox!.close();
      _webBox = null;
    }
    _invalidateCache();
  }

  Future<int> addMovieToHistory({
    required int tmdbId,
    required String title,
    String? posterPath,
    DateTime? watchedAt,
    double? userRating,
    String? notes,
  }) async {
    final item = WatchHistoryItem(
      tmdbId: tmdbId,
      title: title,
      type: 'movie',
      posterPath: posterPath,
      watchedAt: watchedAt ?? DateTime.now(),
      userRating: userRating,
      notes: notes,
    );
    return await insertWatchHistoryItem(item);
  }

  Future<int> addShowToHistory({
    required int tmdbId,
    required String title,
    String? posterPath,
    DateTime? watchedAt,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    double? userRating,
    String? notes,
  }) async {
    final item = WatchHistoryItem(
      tmdbId: tmdbId,
      title: title,
      type: 'tv',
      posterPath: posterPath,
      watchedAt: watchedAt ?? DateTime.now(),
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      userRating: userRating,
      notes: notes,
    );
    return await insertWatchHistoryItem(item);
  }
}
