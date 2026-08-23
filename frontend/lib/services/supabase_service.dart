import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://psupzmalbgplbqfctpzg.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzdXB6bWFsYmdwbGJxZmN0cHpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0OTY0OTAsImV4cCI6MjEwMzA3MjQ5MH0.3A6cbj-yM7GK6ngTZK5FNkTuod8Nnwwjyh_G9jTx6ik';

  static SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase in main()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
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

  // Email / Password Sign Up
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Sign Out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
