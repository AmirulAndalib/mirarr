import 'dart:ui';
import 'package:Mirarr/functions/fetchers/fetch_popular_series.dart';
import 'package:Mirarr/functions/fetchers/fetch_trending_series.dart';
import 'package:Mirarr/functions/fetchers/fetch_series_by_genre.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/seriesPage/function/on_tap_gridview_serie.dart';
import 'package:Mirarr/seriesPage/function/on_tap_serie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:Mirarr/utils/expressive_motion.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' show ClientException;
import 'package:Mirarr/seriesPage/models/serie.dart';
import 'dart:async';
import 'package:Mirarr/seriesPage/UI/customSeriesWidget.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class _TouchMouseScrollBehavior extends MaterialScrollBehavior {
  const _TouchMouseScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

const _seriesScrollBehavior = _TouchMouseScrollBehavior();

class SerieSearchScreen extends StatefulWidget {
  static final GlobalKey<_SerieSearchScreenState> movieSearchKey =
      GlobalKey<_SerieSearchScreenState>();

  const SerieSearchScreen({super.key});
  @override
  _SerieSearchScreenState createState() => _SerieSearchScreenState();
}

class _SerieSearchScreenState extends State<SerieSearchScreen> {
  final apiKey = dotenv.env['TMDB_API_KEY'];

  List<Serie> trendingSeries = [];
  List<Serie> popularSeries = [];
  List<Genre> genres = [];
  Map<int, List<Serie>> seriesByGenre = {};
  late RegionProvider _regionProvider;

  final List<Serie> _dummySeries = List.generate(
    5,
    (index) => Serie(
      name: 'TV Show Title Placeholder',
      posterPath: '',
      overView: 'This is a description placeholder for the tv show loading state.',
      id: -1 - index,
      score: 8.5,
    ),
  );

  final List<Genre> _dummyGenres = [
    Genre(id: -100, name: 'Genre Placeholder 1'),
    Genre(id: -101, name: 'Genre Placeholder 2'),
  ];

  late final Map<int, List<Serie>> _dummySeriesByGenre = {
    -100: List.generate(
      5,
      (index) => Serie(
        name: 'TV Show Title Placeholder',
        posterPath: '',
        overView: 'This is a description placeholder for the tv show loading state.',
        id: -200 - index,
        score: 8.5,
      ),
    ),
    -101: List.generate(
      5,
      (index) => Serie(
        name: 'TV Show Title Placeholder',
        posterPath: '',
        overView: 'This is a description placeholder for the tv show loading state.',
        id: -300 - index,
        score: 8.5,
      ),
    ),
  };

  Future<List<Serie>> _fetchTrendingSeries() async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    return await fetchTrendingSeries(region);
  }

  Future<List<Serie>> _fetchPopularSeries() async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    return await fetchPopularSeries(region);
  }

  Future<void> _loadPrimarySeries() async {
    try {
      final primaryResults = await Future.wait([
        _fetchTrendingSeries(),
        _fetchPopularSeries(),
      ]);

      if (mounted) {
        setState(() {
          trendingSeries = primaryResults[0];
          popularSeries = primaryResults[1];
        });
      }
    } catch (e) {
      debugPrint('Error fetching primary series data: $e');
      if (mounted && e is ClientException) {
        handleNetworkError(e);
      }
    }
  }

  Future<void> _loadGenreSeries() async {
    try {
      final region =
          Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final fetchedGenres = await fetchGenres(region);
      if (!mounted) return;

      // Show genre headers immediately; rows skeleton until each batch lands.
      setState(() {
        genres = fetchedGenres;
      });

      // Browsers limit ~6 connections/host; keep headroom for images.
      // Native can safely fan out all genre requests at once.
      final batchSize = kIsWeb ? 8 : fetchedGenres.length;
      if (batchSize == 0) return;

      for (var i = 0; i < fetchedGenres.length; i += batchSize) {
        final end = (i + batchSize < fetchedGenres.length)
            ? i + batchSize
            : fetchedGenres.length;
        final chunk = fetchedGenres.sublist(i, end);
        final results = await Future.wait(chunk.map((genre) async {
          try {
            final series = await fetchSeriesByGenre(genre.id, region);
            return MapEntry(genre.id, series);
          } catch (e) {
            debugPrint('Failed to fetch series for genre ${genre.name}: $e');
            return MapEntry(genre.id, <Serie>[]);
          }
        }));

        if (!mounted) return;
        setState(() {
          seriesByGenre = {
            ...seriesByGenre,
            for (final entry in results) entry.key: entry.value,
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching genres: $e');
    }
  }

  void handleNetworkError(ClientException e) {
    if (e.message.contains('No address associated with hostname')) {
      // Handle case where there's no internet connection
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            icon: Icon(Icons.wifi_off_rounded, color: colorScheme.error, size: 32),
            title: Text(
              'No Internet Connection',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            content: Text(
              'Please connect to the internet and try again.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      // Handle other network-related errors
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            icon: Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 32),
            title: Text(
              'Network Error',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            content: Text(
              'An error occurred while fetching data. Please try again later.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void _onRegionChanged() {
    checkInternetAndFetchData();
  }

  @override
  void initState() {
    super.initState();
    checkInternetAndFetchData();

    // Add listener for region changes
    _regionProvider = Provider.of<RegionProvider>(context, listen: false);
    _regionProvider.addListener(_onRegionChanged);
  }

  @override
  void dispose() {
    // Remove listener when disposing
    _regionProvider.removeListener(_onRegionChanged);
    super.dispose();
  }

  Future<void> checkInternetAndFetchData() async {
    if (mounted) {
      setState(() {
        trendingSeries = [];
        popularSeries = [];
        genres = [];
        seriesByGenre = {};
      });
    }

    // Primary shelves and genre lists load concurrently.
    await Future.wait([
      _loadPrimarySeries(),
      _loadGenreSeries(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentGenres = genres.isEmpty ? _dummyGenres : genres;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Series',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSectionHeader('Trending TV Shows', null),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ScrollConfiguration(
                    behavior: _seriesScrollBehavior,
                    child: Skeletonizer(
                      enabled: trendingSeries.isEmpty,
                      containersColor: Colors.white.withValues(alpha: 0.05),
                      effect: ShimmerEffect(
                        baseColor: Colors.white.withValues(alpha: 0.05),
                        highlightColor: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: trendingSeries.isEmpty ? _dummySeries.length : trendingSeries.length,
                        itemBuilder: (context, index) {
                          final serie = trendingSeries.isEmpty ? _dummySeries[index] : trendingSeries[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: TvFocusWrapper(
                              autoFocus: index == 0 && trendingSeries.isNotEmpty,
                              onTap: trendingSeries.isEmpty ? () {} : () => onTapSerie(serie.name, serie.id, context),
                              child: CustomSeriesWidget(serie: serie),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Popular TV Shows', null),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ScrollConfiguration(
                    behavior: _seriesScrollBehavior,
                    child: Skeletonizer(
                      enabled: popularSeries.isEmpty,
                      containersColor: Colors.white.withValues(alpha: 0.05),
                      effect: ShimmerEffect(
                        baseColor: Colors.white.withValues(alpha: 0.05),
                        highlightColor: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: popularSeries.isEmpty ? _dummySeries.length : popularSeries.length,
                        itemBuilder: (context, index) {
                          final serie = popularSeries.isEmpty ? _dummySeries[index] : popularSeries[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: TvFocusWrapper(
                              onTap: popularSeries.isEmpty ? () {} : () => onTapSerie(serie.name, serie.id, context),
                              child: CustomSeriesWidget(serie: serie),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final genre = currentGenres[index];
                final genreLoading =
                    genres.isNotEmpty && !seriesByGenre.containsKey(genre.id);
                final seriesList = genres.isEmpty
                    ? _dummySeriesByGenre[genre.id]
                    : genreLoading
                        ? _dummySeries
                        : seriesByGenre[genre.id];

                return Skeletonizer(
                  enabled: genres.isEmpty || genreLoading,
                  containersColor: Colors.white.withValues(alpha: 0.05),
                  effect: ShimmerEffect(
                    baseColor: Colors.white.withValues(alpha: 0.05),
                    highlightColor: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        genre.name,
                        genreLoading || seriesByGenre[genre.id] == null
                            ? null
                            : () => onTapGridSerie(
                                seriesByGenre[genre.id] ?? [], context),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 320,
                        child: ScrollConfiguration(
                          behavior: _seriesScrollBehavior,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: seriesList?.length ?? 0,
                            itemBuilder: (context, itemIndex) {
                              final serie = seriesList?[itemIndex];
                              if (serie == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: TvFocusWrapper(
                                  onTap: genres.isEmpty || genreLoading
                                      ? () {}
                                      : () => onTapSerie(
                                          serie.name, serie.id, context),
                                  child: CustomSeriesWidget(serie: serie),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: currentGenres.length,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          if (onTap != null)
            ExpressiveInteractiveContainer(
              onTap: onTap,
              borderRadius: 20,
              pressedBorderRadius: 28,
              speed: ExpressiveSpeed.fast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
