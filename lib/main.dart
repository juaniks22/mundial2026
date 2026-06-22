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

      home: const HomeScreen(),
    );
  }
}
