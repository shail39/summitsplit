import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/trip_detail_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/user_profile.dart';

void main() => runApp(const SummitSplitApp());

// Track the URL user was trying to reach before onboarding
String? _pendingDeepLink;

final _router = GoRouter(
  redirect: (context, state) async {
    final profile = await UserProfile.load();
    final isOnboarding = state.matchedLocation == '/onboarding';
    if (profile == null && !isOnboarding) {
      // Save the original URL so we can return to it after onboarding
      if (state.matchedLocation != '/') {
        _pendingDeepLink = state.uri.toString();
      }
      return '/onboarding';
    }
    if (profile != null && isOnboarding) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => OnboardingScreen(pendingDeepLink: _pendingDeepLink)),
    GoRoute(
      path: '/trips/:id',
      builder: (_, state) => TripDetailScreen(tripId: state.pathParameters['id']!),
    ),
  ],
);

// Global theme notifier for dark mode
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'dark') _mode = ThemeMode.dark;
    else if (saved == 'light') _mode = ThemeMode.light;
    else _mode = ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
  }

  void cycle() {
    switch (_mode) {
      case ThemeMode.system: setMode(ThemeMode.light);
      case ThemeMode.light: setMode(ThemeMode.dark);
      case ThemeMode.dark: setMode(ThemeMode.system);
    }
  }
}

final themeNotifier = ThemeNotifier();

class SummitSplitApp extends StatefulWidget {
  const SummitSplitApp({super.key});

  @override
  State<SummitSplitApp> createState() => _SummitSplitAppState();
}

class _SummitSplitAppState extends State<SummitSplitApp> {
  bool _showSplash = true;

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366f1),
      primary: const Color(0xFF6366f1),
      secondary: const Color(0xFFf59e0b),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: GoogleFonts.poppinsTextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF6366f1),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366f1),
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(
          onComplete: () => setState(() => _showSplash = false),
        ),
      );
    }
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (_, __) => MaterialApp.router(
        title: 'Summit Split',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: themeNotifier.mode,
      ),
    );
  }
}
