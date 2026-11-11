import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/main.dart';
import 'package:kateringkita_pbl/providers/session_provider.dart';
import 'package:kateringkita_pbl/providers/theme_provider.dart';
import 'package:kateringkita_pbl/screens/auth/login_screen.dart';
import 'package:kateringkita_pbl/services/api_client.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('token ditolak server (401) → splash membuka layar masuk',
      (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final api = ApiClient(
      MockClient((_) async => http.Response(
          '{"error":{"code":"UNAUTHENTICATED","message":"Sesi berakhir."}}', 401)),
      readToken: () async => 'tok',
      baseUrl: 'http://api.test/v1',
    );
    final session = SessionProvider(
      api,
      readToken: () async => 'tok',
      saveToken: (_) async {},
      clearToken: () async {},
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(initialDark: false)),
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
        ],
        child: const KateringKitaApp(),
      ),
    );
    expect(find.byType(KateringKitaApp), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(session.isLoggedIn, isFalse);
  });
}
