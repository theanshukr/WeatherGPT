// ignore_for_file: unused_field, unused_import
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  // GET Request Implementation
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    /*
    final uri = Uri.parse('${ApiConstants.devBaseUrl}$endpoint').replace(
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );
    final response = await _client.get(
      uri,
      headers: ApiConstants.defaultHeaders(token: _authToken),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('API Error [${response.statusCode}]: ${response.body}');
    }
    */
    return null;
  }

  // POST Request Implementation
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    /*
    final uri = Uri.parse('${ApiConstants.devBaseUrl}$endpoint');
    final response = await _client.post(
      uri,
      headers: ApiConstants.defaultHeaders(token: _authToken),
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('API Error [${response.statusCode}]: ${response.body}');
    }
    */
    return null;
  }
}
