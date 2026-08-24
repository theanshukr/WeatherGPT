import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/api_constants.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://psupzmalbgplbqfctpzg.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzdXB6bWFsYmdwbGJxZmN0cHpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0OTY0OTAsImV4cCI6MjEwMzA3MjQ5MH0.3A6cbj-yM7GK6ngTZK5FNkTuod8Nnwwjyh_G9jTx6ik';

  static SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase in main()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  }

  // Get current user JWT access token
  static String? get currentAccessToken =>
      client.auth.currentSession?.accessToken;

  // Get current Supabase Auth User ID
  static String? get currentUserId => client.auth.currentUser?.id;

  // 1-Tap Anonymous Guest Login
  static Future<AuthResponse?> signInAnonymously() async {
    try {
      if (client.auth.currentUser == null) {
        return await client.auth.signInAnonymously();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Email / Password Sign In
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Email / Password Sign Up — uses backend direct registration to avoid
  // Supabase free-tier SMTP email rate limits.  Does NOT fall back to
  // client.auth.signUp() which would send a confirmation email.
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? persona,
  }) async {
    // Attempt 1: Direct backend verified registration (instant & bypasses email quota limits)
    try {
      final regUri = Uri.parse('${ApiConstants.baseUrl}/auth/register');
      final regRes = await http.post(
        regUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName ?? 'WeatherGPT User',
          'persona': persona ?? 'general',
        }),
      ).timeout(const Duration(seconds: 8));

      if (regRes.statusCode == 200) {
        // Backend created & verified the user — now sign in normally
        return await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      // Backend returned an error (e.g. 500 DB unreachable).
      // Surface a clear message instead of silently falling back to signUp().
      final detail = regRes.body.isNotEmpty ? regRes.body : 'Unknown error';
      throw Exception(
        'Backend registration returned ${regRes.statusCode}: $detail. '
        'Ensure the backend server is running and its database is reachable.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Could not reach the backend server for registration. '
        'Check your connection and try again. ($e)',
      );
    }
  }

  // Sign Out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
