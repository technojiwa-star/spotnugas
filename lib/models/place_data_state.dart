/// Explicit states for place queries, handling loading, empty, offline, and error conditions.
sealed class PlaceDataState<T> {
  const PlaceDataState();

  bool get isLoading => this is PlaceDataLoading<T>;
  bool get isSuccess => this is PlaceDataSuccess<T>;
  bool get isEmpty => this is PlaceDataEmpty<T>;
  bool get isOffline => this is PlaceDataOffline<T>;
  bool get isError => this is PlaceDataError<T>;

  T? get dataOrNull => switch (this) {
    PlaceDataSuccess<T>(data: final d) => d,
    PlaceDataOffline<T>(data: final d) => d,
    _ => null,
  };
}

/// Initial uninitialized state before any fetch has begun.
final class PlaceDataInitial<T> extends PlaceDataState<T> {
  const PlaceDataInitial();
}

/// Active asynchronous query in flight.
final class PlaceDataLoading<T> extends PlaceDataState<T> {
  final String? message;
  const PlaceDataLoading({this.message});
}

/// Successfully retrieved places.
final class PlaceDataSuccess<T> extends PlaceDataState<T> {
  final T data;
  final bool hasMore;
  final String? nextPageToken;

  const PlaceDataSuccess(this.data, {this.hasMore = false, this.nextPageToken});
}

/// Zero results found (e.g., search text matched nothing or radius too tight).
final class PlaceDataEmpty<T> extends PlaceDataState<T> {
  final String message;
  final String? actionableSuggestion;

  const PlaceDataEmpty({
    this.message = 'Tidak ada tempat nugas ditemukan di sekitar sini',
    this.actionableSuggestion =
        'Coba ubah kata kunci pencarian atau perluas radius pencarian.',
  });
}

/// Operating without an active internet connection; serving cached session data.
final class PlaceDataOffline<T> extends PlaceDataState<T> {
  final T data;
  final DateTime? cachedAt;
  final String message;

  const PlaceDataOffline(
    this.data, {
    this.cachedAt,
    this.message = 'Menampilkan data tersimpan dalam mode offline',
  });
}

/// Query failed (network failure, quota limit, or API error).
final class PlaceDataError<T> extends PlaceDataState<T> {
  final String message;
  final Object? error;
  final bool canRetry;

  const PlaceDataError({
    required this.message,
    this.error,
    this.canRetry = true,
  });
}
