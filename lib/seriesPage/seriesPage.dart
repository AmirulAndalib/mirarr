import 'dart:ui';

import 'package:Mirarr/functions/fetchers/fetch_popular_series.dart';
import 'package:Mirarr/functions/fetchers/fetch_trending_series.dart';
import 'package:Mirarr/functions/fetchers/fetch_series_by_genre.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/seriesPage/function/on_tap_gridview_serie.dart';
import 'package:Mirarr/seriesPage/function/on_tap_serie.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:Mirarr/seriesPage/models/serie.dart';
import 'dart:async';
import 'package:Mirarr/seriesPage/UI/customSeriesWidget.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

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

  Future<void> _fetchGenresAndSeries() async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    try {
      final fetchedGenres = await fetchGenres(region);
      final tasks = fetchedGenres.map((genre) async {
        final series = await fetchSeriesByGenre(genre.id, region);
        return MapEntry(genre.id, series);
      });
      final results = await Future.wait(tasks);

      if (mounted) {
        setState(() {
          genres = fetchedGenres;
          seriesByGenre = Map.fromEntries(results);
        });
      }
    } catch (e) {
      throw Exception('Failed to load series by genre');
    }
  }

  Future<void> _fetchTrendingSeries() async {
    try {
      final region =
          Provider.of<RegionProvider>(context, listen: false).currentRegion;
      trendingSeries = await fetchTrendingSeries(region);
      setState(() {
        trendingSeries = trendingSeries;
      });
    } catch (e) {
      throw Exception('Failed to load trending series data');
    }
  }

  Future<void> _fetchPopularSeries() async {
    try {
      final region =
          Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final series = await fetchPopularSeries(region);
      setState(() {
        popularSeries = series;
      });
    } catch (e) {
      throw Exception('Failed to load popular series data');
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
                  checkInternetAndFetchData();
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
    setState(() {
      trendingSeries = [];
      popularSeries = [];
      genres = [];
      seriesByGenre = {};
    });
    _fetchTrendingSeries();
    _fetchPopularSeries();
    await _fetchGenresAndSeries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionHeader('Trending TV Shows', null),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: Skeletonizer(
                  enabled: trendingSeries.isEmpty,
                  containersColor: colorScheme.surfaceContainerHigh,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: trendingSeries.isEmpty ? _dummySeries.length : trendingSeries.length,
                    itemBuilder: (context, index) {
                      final serie = trendingSeries.isEmpty ? _dummySeries[index] : trendingSeries[index];
                      final widget = Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: TvFocusWrapper(
                          autoFocus: index == 0 && trendingSeries.isNotEmpty,
                          onTap: trendingSeries.isEmpty ? () {} : () => onTapSerie(serie.name, serie.id, context),
                          child: CustomSeriesWidget(serie: serie),
                        ),
                      );
                      if (trendingSeries.isEmpty) {
                        final double opacity = (1.0 - (index * 0.18)).clamp(0.1, 1.0);
                        return Opacity(opacity: opacity, child: widget);
                      }
                      return widget;
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
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: Skeletonizer(
                  enabled: popularSeries.isEmpty,
                  containersColor: colorScheme.surfaceContainerHigh,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: popularSeries.isEmpty ? _dummySeries.length : popularSeries.length,
                    itemBuilder: (context, index) {
                      final serie = popularSeries.isEmpty ? _dummySeries[index] : popularSeries[index];
                      final widget = Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: TvFocusWrapper(
                          onTap: popularSeries.isEmpty ? () {} : () => onTapSerie(serie.name, serie.id, context),
                          child: CustomSeriesWidget(serie: serie),
                        ),
                      );
                      if (popularSeries.isEmpty) {
                        final double opacity = (1.0 - (index * 0.18)).clamp(0.1, 1.0);
                        return Opacity(opacity: opacity, child: widget);
                      }
                      return widget;
                    },
                  ),
                ),
              ),
            ),
            for (var genre in (genres.isEmpty ? _dummyGenres : genres))
              Skeletonizer(
                enabled: genres.isEmpty,
                containersColor: colorScheme.surfaceContainerHigh,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      genre.name,
                      genres.isEmpty ? null : () => onTapGridSerie(seriesByGenre[genre.id]!, context),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: genres.isEmpty
                              ? (_dummySeriesByGenre[genre.id]?.length ?? 0)
                              : (seriesByGenre[genre.id]?.length ?? 0),
                          itemBuilder: (context, index) {
                            final serie = genres.isEmpty
                                ? _dummySeriesByGenre[genre.id]![index]
                                : seriesByGenre[genre.id]![index];
                            final widget = Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: TvFocusWrapper(
                                onTap: genres.isEmpty ? () {} : () => onTapSerie(serie.name, serie.id, context),
                                child: CustomSeriesWidget(serie: serie),
                              ),
                            );
                            if (genres.isEmpty) {
                              final double opacity = (1.0 - (index * 0.18)).clamp(0.1, 1.0);
                              return Opacity(opacity: opacity, child: widget);
                            }
                            return widget;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
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
            ),
        ],
      ),
    );
  }
}

