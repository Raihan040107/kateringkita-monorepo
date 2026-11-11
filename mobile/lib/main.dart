import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_colors.dart';
import 'core/app_router.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'data/app_database.dart';
import 'data/token_store.dart';
import 'providers/cart_provider.dart';
import 'providers/session_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_client.dart';

/// Navigator & messenger global: dipakai saat sesi ditolak server (401) dan
/// untuk banner notifikasi dari layar mana pun.
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = SharedPreferencesAsync();
  final isDarkInitial = await prefs.getBool(ThemeProvider.prefKey) ?? false;
  AppColors.isDarkMode = isDarkInitial;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDarkInitial ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDarkInitial ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDarkInitial ? AppColors.darkBackground : AppColors.lightBackground,
      systemNavigationBarIconBrightness:
          isDarkInitial ? Brightness.light : Brightness.dark,
    ),
  );

  late final SessionProvider session;
  final api = ApiClient(
    http.Client(),
    readToken: TokenStore.readToken,
    onUnauthenticated: () async {
      // token kedaluwarsa/dicabut: hanya sekali, lalu ke layar masuk
      if (!session.isLoggedIn) return;
      await TokenStore.clear();
      session.clear();
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    },
  );
  session = SessionProvider(api);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialDark: isDarkInitial),
        ),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        Provider<AppDb>(
          create: (_) => AppDb(),
          dispose: (_, db) => db.close(),
        ),
      ],
      child: const KateringKitaApp(),
    ),
  );
}

class KateringKitaApp extends StatelessWidget {
  const KateringKitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    AppColors.isDarkMode = themeProvider.isDarkMode;

    return MaterialApp(
      title: 'KateringKita',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: AppRouter.initialRoute,
      routes: AppRouter.routes,
    );
  }
}
