// lib/main.dart
//
// Punto de entrada. Responsabilidades:
//   1. Inicializar Hive y abrir las boxes antes de runApp.
//   2. Envolver la app en ProviderScope (Riverpod).
//   3. Configurar el tema visual.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/api_constants.dart';
import 'presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Inicialización de Hive ──────────────────────────────────────────────
  // Usa el directorio de documentos del dispositivo (no requiere path_provider
  // manual, hive_flutter lo maneja internamente).
  await Hive.initFlutter();

  // Abrimos las dos boxes que necesita la app.
  // Hive las crea si no existen; las carga si ya existen.
  await Future.wait([
    Hive.openBox<int>(HiveConstants.statusBox),    // estados personales
    Hive.openBox<bool>(HiveConstants.extraTimeBox),// alargue
    Hive.openBox<String>(HiveConstants.cacheBox),  // caché del fixture
  ]);

  runApp(
    // ProviderScope es el contenedor raíz de todos los providers Riverpod.
    const ProviderScope(
      child: Mundial2026App(),
    ),
  );
}

class Mundial2026App extends StatelessWidget {
  const Mundial2026App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mundial 2026',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,

      // ── Tema Claro (Estilo Mercado Pago) ──────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009EE3), // Azul Mercado Pago
          primary: const Color(0xFF009EE3),
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1A1A1A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(
          bodyColor: const Color(0xFF1A1A1A),
          displayColor: const Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 1,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                // Main content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'fifa logo wc26.jpg',
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Mundial 2026',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Etaa locuraaa',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF009EE3),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF009EE3),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Bottom Messi image
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'messi levantando copa del mundo.jpg',
                        height: 230,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

