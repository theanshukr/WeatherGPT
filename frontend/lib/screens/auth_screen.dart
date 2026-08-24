import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../services/supabase_service.dart';
import 'main_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;

  static const String testEmail = 'test@weathergpt.com';
  static const String testPassword = 'WeatherTest@2026';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.signInAnonymously();
    } catch (_) {}
    _navigateToHome();
    if (mounted) setState(() => _isLoading = false);
  }

  /// Proper Auth Login using the designated Testing Account.
  ///
  /// Retries sign-in for transient errors and only falls back to sign-up
  /// when Supabase explicitly says the credentials are invalid (meaning the
  /// user was never created).  This avoids burning the free-tier SMTP email
  /// quota on every retry.
  Future<void> _handleTestAccountLogin() async {
    _loginEmailController.text = testEmail;
    _loginPasswordController.text = testPassword;
    setState(() => _isLoading = true);

    try {
      // 1. Attempt sign-in with retry for transient/network errors
      AuthException? lastAuthErr;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          await SupabaseService.signInWithEmail(
            email: testEmail,
            password: testPassword,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logged in successfully with Testing Account!'),
                backgroundColor: AppColors.emeraldNeon,
              ),
            );
          }
          _navigateToHome();
          return; // success — exit early
        } on AuthException catch (e) {
          lastAuthErr = e;
          // "invalid_credentials" means the user doesn't exist yet — no point retrying
          if (e.statusCode == '400') break;
          // Rate-limit — surface immediately, don't retry
          if (e.statusCode == '429') break;
          // Transient error — wait briefly then retry
          await Future.delayed(const Duration(milliseconds: 800));
        } catch (_) {
          // Network / timeout — wait briefly then retry
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }

      // 2. Only attempt sign-up if the user genuinely doesn't exist
      if (lastAuthErr != null && lastAuthErr.statusCode == '400') {
        try {
          await SupabaseService.signUpWithEmail(
            email: testEmail,
            password: testPassword,
          );
          _navigateToHome();
          return;
        } catch (signupErr) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Test account setup failed: $signupErr'),
                backgroundColor: AppColors.alertCrimson,
              ),
            );
          }
        }
      } else {
        // Rate-limit or network error — show a helpful message
        final msg = lastAuthErr != null
            ? 'Supabase auth error: ${lastAuthErr.message}'
            : 'Could not reach Supabase. Check your internet connection.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.alertCrimson),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.signInWithEmail(email: email, password: password);
      _navigateToHome();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.alertCrimson),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: AppColors.alertCrimson),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignUp() async {
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.signUpWithEmail(email: email, password: password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Logging you in...'),
            backgroundColor: AppColors.emeraldNeon,
          ),
        );
      }
      _navigateToHome();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.alertCrimson),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e'), backgroundColor: AppColors.alertCrimson),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient glowing aura
            if (isDark) ...[
              Positioned(
                top: -80,
                right: -40,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emeraldNeon.withValues(alpha: 0.14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldNeon.withValues(alpha: 0.22),
                        blurRadius: 130,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        blurRadius: 120,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // Brand Icon & Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF00FF87), Color(0xFF059669)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emeraldNeon.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WeatherGPT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'AI Weather & Early Warning',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Tab Bar Selector (Sign In vs Create Account)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: isDark ? Colors.black : Colors.white,
                      unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Create Account'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tab Views Content
                  SizedBox(
                    height: 300,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(isDark),
                        _buildSignupForm(isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'TESTING ACCOUNT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Proper Testing Account Login Button (Authenticates via Supabase Auth)
                  GestureDetector(
                    onTap: _isLoading ? null : _handleTestAccountLogin,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: isDark
                              ? AppColors.emeraldNeon.withValues(alpha: 0.4)
                              : AppColors.emeraldDark.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 20,
                            color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sign In with Testing Account',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Continue as Guest Button
                  Center(
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _handleGuestLogin,
                      icon: Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      label: Text(
                        'Continue as Guest',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
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

  Widget _buildLoginForm(bool isDark) {
    return Column(
      children: [
        _buildTextField(
          controller: _loginEmailController,
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _loginPasswordController,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureLoginPassword,
          isDark: isDark,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureLoginPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
          ),
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          label: 'Sign In',
          onPressed: _handleEmailLogin,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSignupForm(bool isDark) {
    return Column(
      children: [
        _buildTextField(
          controller: _signupEmailController,
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _signupPasswordController,
          hint: 'Create password (min 6 chars)',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureSignupPassword,
          isDark: isDark,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignupPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            onPressed: () => setState(() => _obscureSignupPassword = !_obscureSignupPassword),
          ),
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          label: 'Create Account',
          onPressed: _handleEmailSignUp,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        decoration: InputDecoration(
          icon: Icon(icon, size: 20, color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark),
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          elevation: 4,
          shadowColor: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark).withValues(alpha: 0.4),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
      ),
    );
  }
}
