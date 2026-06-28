import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/usuario.dart';
import 'screens/login_screen.dart';
import 'screens/boleta_screen.dart';
import 'config.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

await Supabase.initialize(
  url: Config.supabaseUrl,
  anonKey: Config.supabaseKey,
);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boletas Digitales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade800),
        useMaterial3: true,
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('usuario_sesion');
    final fechaRaw = prefs.getString('fecha_login');

    bool sesionValida = false;

    if (raw != null && fechaRaw != null) {
      final fechaLogin = DateTime.tryParse(fechaRaw);
      if (fechaLogin != null) {
        final diasPasados = DateTime.now().difference(fechaLogin).inDays;
        if (diasPasados < 30) {
          sesionValida = true;
        }
      }
    }

    if (!mounted) return;

    if (sesionValida) {
      final data = jsonDecode(raw!);
      final usuario = Usuario(
        id: data['id'],
        usuario: data['usuario'],
        nombre: data['nombre'],
        area: data['area'],
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BoletaScreen(usuarioActual: usuario)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade800,
      body: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}