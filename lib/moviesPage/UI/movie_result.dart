import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Mirarr/services/api_client.dart';
import 'dart:convert';
import 'package:provider/provider.dart';

class MovieSearchResult extends StatelessWidget {
  final Movie movie;

  const MovieSearchResult({super.key, required this.movie});

  Future<bool> checkAvailability(int movieId, String region) async {
    final baseUrl = getBaseUrl(region);
    final apiKey = dotenv.env['TMDB_API_KEY'];
    final response = await apiClient.get(
      Uri.parse('${baseUrl}movie/$movieId/watch/providers?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final Map<String, dynamic> results = data['results'];
      return results.isNotEmpty;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (movie.backdropPath != null && movie.backdropPath!.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: '${getImageBaseUrl(region)}/t/p/w780${movie.backdropPath}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHigh),
                  errorWidget: (context, url, err) => Container(color: colorScheme.surfaceContainerHigh),
                ),
              )
            else if (movie.posterPath.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: '${getImageBaseUrl(region)}/t/p/w500${movie.posterPath}',
                  fit: BoxFit.cover,
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Score Pill Badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      movie.score != null ? movie.score!.toStringAsFixed(1) : '0.0',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Availability Icon Badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: FutureBuilder<bool>(
                  future: checkAvailability(movie.id, region),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Icon(
                      snapshot.data == true ? Icons.download_rounded : Icons.cloud_off_rounded,
                      color: snapshot.data == true ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      size: 14,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (movie.releaseDate.isNotEmpty)
                    Text(
                      movie.releaseDate.contains('-')
                          ? movie.releaseDate.split('-')[0]
                          : movie.releaseDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
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
}

