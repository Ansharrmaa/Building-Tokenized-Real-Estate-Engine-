import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';

/// Service for communicating with the backend REST API.
class ApiService {
  static String get _baseUrl => '${Uri.base.origin}/api/v1';
  static final http.Client _client = http.Client();

  /// Search for properties and locations.
  /// Returns an empty list on any error rather than throwing.
  static Future<List<SearchResult>> search(String query, {String? country}) async {
    if (query.trim().isEmpty && (country == null || country.isEmpty)) return [];

    try {
      final params = <String, String>{'q': query};
      if (country != null && country.isNotEmpty) {
        params['country'] = country;
      }

      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: params);
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return [];

      final decoded = json.decode(response.body);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => SearchResult.fromJson(json))
          .whereType<SearchResult>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch properties by IDs with optional filters.
  /// Returns an empty list on any error.
  static Future<List<Property>> getProperties({
    List<int>? ids,
    String? propertyType,
    double? minValue,
    double? maxValue,
    int? minToken,
    int? maxToken,
  }) async {
    try {
      final params = <String, String>{};

      if (ids != null && ids.isNotEmpty) {
        params['ids'] = ids.join(',');
      }
      if (propertyType != null && propertyType.isNotEmpty) {
        params['property_type'] = propertyType;
      }
      if (minValue != null) {
        params['min_value'] = minValue.toStringAsFixed(0);
      }
      if (maxValue != null) {
        params['max_value'] = maxValue.toStringAsFixed(0);
      }
      if (minToken != null) {
        params['min_token'] = minToken.toString();
      }
      if (maxToken != null) {
        params['max_token'] = maxToken.toString();
      }

      final uri = Uri.parse('$_baseUrl/properties').replace(queryParameters: params);
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) return [];

      final decoded = json.decode(response.body);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => Property.fromJson(json))
          .whereType<Property>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
