final Map<String, dynamic> seasonsApiCache = {};

void clearSeasonsApiCache() {
  seasonsApiCache.clear();
}

Future<T> cachedSeasonsApiCall<T>(
    String key, Future<T> Function() apiCall) async {
  if (seasonsApiCache.containsKey(key)) {
    return seasonsApiCache[key] as T;
  }
  final result = await apiCall();
  seasonsApiCache[key] = result;
  return result;
}
