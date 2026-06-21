// lib/main.dart
//
// Punto de entrada. Responsabilidades:
//   1. Inicializar Hive y abrir las boxes antes de runApp.
//   2. Envolver la app en ProviderScope (Riverpod).
//   3. Configurar el tema visual.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      themeMode: ThemeMode.dark,

      // ── Tema oscuro (fútbol = noche) ──────────────────────────────────
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00AA55), // verde campo de fútbol
          brightness: Brightness.dark,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E2E),
          elevation: 2,
        ),
      ),

      // ── Tema claro (fallback) ─────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00AA55),
        ),
      ),

      home: const HomeScreen(),
    );
  }
}
