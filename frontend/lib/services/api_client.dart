import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

import 'supabase_service.dart';

/// Thrown when a request can't reach the backend at all (wrong IP,
/// backend not running, no network, timeout). Distinct from a normal
/// HTTP error response, so calling code can tell "server is unreachable"
/// apart from "server answered with an error" and show the user something
/// honest instead of silently swapping in mock data.
class ApiUnreachableException implements Exception {
  final String message;
  ApiUnreachableException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  String? get activeToken => _authToken ?? SupabaseService.currentAccessToken;

  // GET Request Implementation
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      final base = ApiConstants.baseUrl;
      final uri = Uri.parse('$base$endpoint').replace(
        queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
      );
      
      final response = await _client.get(
        uri,
        headers: ApiConstants.defaultHeaders(token: activeToken),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        developer.log('API Error [${response.statusCode}]: ${response.body}', name: 'ApiClient');
        return null;
      }
    } catch (e) {
      developer.log('HTTP GET exception for $endpoint: $e', name: 'ApiClient');
      throw ApiUnreachableException(
        'Could not reach backend at ${ApiConstants.baseUrl}$endpoint. '
        'Check that the server is running and reachable ($e)',
      );
    }
  }

  // POST Request Implementation
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final base = ApiConstants.baseUrl;
      final uri = Uri.parse('$base$endpoint');

      final response = await _client.post(
        uri,
        headers: ApiConstants.defaultHeaders(token: activeToken),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        developer.log('API Error [${response.statusCode}]: ${response.body}', name: 'ApiClient');
        return null;
      }
    } catch (e) {
      developer.log('HTTP POST exception for $endpoint: $e', name: 'ApiClient');
      throw ApiUnreachableException(
        'Could not reach backend at ${ApiConstants.baseUrl}$endpoint. '
        'Check that the server is running and reachable ($e)',
      );
    }
  }
}
