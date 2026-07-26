import 'dart:ui';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

class CustomMovieWidget extends StatelessWidget {
  static final Map<int, bool> _availabilityCache = {};

  final Movie movie;
  final bool showAvailability;
  final bool isWatched;

  const CustomMovieWidget({
    super.key,
    required this.movie,
    this.showAvailability = true,
    this.isWatched = false,
  });

  Future<bool> checkAvailability(int movieId, BuildContext context) async {
    if (movieId < 0) return false;
    if (_availabilityCache.containsKey(movieId)) {
      return _availabilityCache[movieId]!;
    }
    final baseUrl = getBaseUrl(Provider.of<RegionProvider>(context).currentRegion);
    final apiKey = dotenv.env['TMDB_API_KEY'];
    final response = await http.get(
      Uri.parse('${baseUrl}movie/$movieId/watch/providers?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final Map<String, dynamic> results = data['results'];
      _availabilityCache[movieId] = results.isNotEmpty;
      return results.isNotEmpty;
    } else {
      _availabilityCache[movieId] = false;
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 500,
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            if (movie.posterPath.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: '${getImageBaseUrl(Provider.of<RegionProvider>(context).currentRegion)}/t/p/w500${movie.posterPath}',
                  fit: BoxFit.cover,
                  color: isWatched ? Colors.black.withValues(alpha: 0.4) : null,
                  colorBlendMode: isWatched ? BlendMode.darken : null,
                  placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHigh),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.movie, size: 48, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Rating Badge Pill
            if (movie.score != null && movie.score! > 0)
              Positioned(
                top: 12,
                left: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            movie.score!.toStringAsFixed(1),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Watched Badge
            if (isWatched)
              Positioned(
                top: 12,
                right: showAvailability ? 54 : 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'WATCHED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Availability Icon
            if (showAvailability)
              Positioned(
                top: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: FutureBuilder<bool>(
                        future: checkAvailability(movie.id, context),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return Icon(
                            snapshot.data == true ? Icons.download_rounded : Icons.cloud_off_rounded,
                            size: 18,
                            color: snapshot.data == true ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            // Details
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (movie.releaseDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      movie.releaseDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

