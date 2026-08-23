import 'package:flutter/material.dart';
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
      _navigateToHome();
    } catch (e) {
      _navigateToHome(); // Fallback into guest mode
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
            // Background ambient glow
            if (isDark)
              Positioned(
                top: -80,
                right: -40,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emeraldNeon.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldNeon.withValues(alpha: 0.18),
                        blurRadius: 120,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),

            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Brand Icon & Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.emeraldNeon.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.cloud_rounded,
                          color: AppColors.emeraldNeon,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WeatherGPT',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          Text(
                            'AI Climate & Voice Assistant',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.emeraldNeon,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Create Account'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form Container
                  SizedBox(
                    height: 300,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // LOGIN TAB
                        _buildLoginForm(isDark),
                        // SIGN UP TAB
                        _buildSignUpForm(isDark),
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
                          'OR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 1-Tap Guest Access
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      ),
                      onPressed: _isLoading ? null : _handleGuestLogin,
                      icon: const Icon(Icons.flash_on_rounded, color: AppColors.sunnyGold, size: 20),
                      label: const Text(
                        'Continue as Guest (Instant Access)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Footer Note
                  Center(
                    child: Text(
                      'Secured with Supabase PostgreSQL Auth • 24/7 Cloud',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.emeraldNeon),
                  ),
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
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            labelText: 'Email Address',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            labelText: 'Password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: IconButton(
              icon: Icon(_obscureLoginPassword ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldNeon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isLoading ? null : _handleEmailLogin,
            child: const Text(
              'Sign In',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _signupEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            labelText: 'Email Address',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _signupPasswordController,
          obscureText: _obscureSignupPassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            labelText: 'Password (min 6 chars)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: IconButton(
              icon: Icon(_obscureSignupPassword ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscureSignupPassword = !_obscureSignupPassword),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldNeon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isLoading ? null : _handleEmailSignUp,
            child: const Text(
              'Create Account',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
