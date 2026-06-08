import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/login_screen.dart';
import 'screens/motorista/painel_motorista.dart';
import 'screens/operador/painel_operador.dart';
import 'screens/administrativo/painel_admin.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lê a tag ENVIRONMENT passada pelo terminal (o padrão caso não passe nada será dev)
  const String env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

  await Firebase.initializeApp(
    options: env == 'prod' 
        ? prod.DefaultFirebaseOptions.currentPlatform 
        : dev.DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const DockFlowApp());
}

class DockFlowApp extends StatelessWidget {
  const DockFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dock Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D7D46),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const RoleRouter();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase() ?? '';

    // LÓGICA DE ROTEAMENTO (MVP)
    if (email.endsWith('@admin.dockflow.com')) {
      return const PainelAdmin();
    } else if (email.endsWith('@operador.dockflow.com') || email.endsWith('@docas.com')) {
      return const PainelOperador();
    }
    
    return const PainelMotorista();
  }
}