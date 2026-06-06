import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/exchange_rate_alert_service.dart';
import 'services/live_chat_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ExchangeRateAlertService()),
        ChangeNotifierProvider(create: (_) => LiveChatService()..load()),
      ],
      child: const InterFlexApp(),
    ),
  );
}

class InterFlexApp extends StatelessWidget {
  const InterFlexApp({super.key});

  static const Color _primary = Color(0xFF0E7A5F);
  static const Color _secondary = Color(0xFF0F9AA7);
  static const Color _surface = Color(0xFFFAFEFB);
  static const Color _background = Color(0xFFF2F3F5);
  static const Color _outline = Color(0xFFC9DCD0);
  static const Color _text = Color(0xFF17231E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INTERFLEX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          primary: _primary,
          secondary: _secondary,
          tertiary: const Color(0xFFF4B740),
          surface: _surface,
          surfaceContainerHighest: const Color(0xFFE4F0E8),
          outline: _outline,
          error: const Color(0xFFD94A3A),
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: _text,
          displayColor: _text,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: _background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: _text),
          titleTextStyle: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            overlayColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            overlayColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: _surface.withAlpha(244),
          elevation: 3,
          shadowColor: const Color(0xFF0D3D2F).withAlpha(30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _outline),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface.withAlpha(242),
          labelStyle: const TextStyle(color: Color(0xFF52685E)),
          hintStyle: const TextStyle(color: Color(0xFF7B9086)),
          prefixIconColor: const Color(0xFF52685E),
          suffixIconColor: const Color(0xFF52685E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD94A3A)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD94A3A), width: 2),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _surface.withAlpha(242),
          indicatorColor: _primary.withAlpha(38),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _primary
                  : const Color(0xFF64766D),
            );
          }),
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
