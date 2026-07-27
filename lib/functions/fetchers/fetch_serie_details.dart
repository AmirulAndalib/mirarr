import 'package:Mirarr/functions/get_base_url.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/services/api_client.dart';
import 'dart:convert';

final apiKey = dotenv.env['TMDB_API_KEY'];

Future<Map<String, dynamic>> fetchSerieDetails(
    int serieId, String region) async {
  final baseUrl = getBaseUrl(region);
  try {
    final response = await apiClient.get(
      Uri.parse('${baseUrl}tv/$serieId?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      return responseData;
    } else {
      throw Exception('Failed to load serie details');
    }
  } catch (e) {
    throw Exception('Failed to load serie details');
  }
}
