import 'package:flutter/material.dart';

import 'api.dart';
import 'home_screen.dart';
import 'login_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() => runApp(const MiApp());

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Si el servidor responde 401 en cualquier pantalla, se vuelve al login (igual que la web).
    ApiClient.instance.onSesionExpirada = () => navigatorKey.currentState
        ?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);

    return MaterialApp(
      title: 'App Usuarios',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: ApiClient.instance.restaurarSesion(),
        builder: (context, snap) {
          if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return snap.data! ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
