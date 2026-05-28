import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/motorista/painel_motorista.dart';
import 'screens/operador/painel_operador.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
    // Operadores têm email com domínio @operador.dockflow ou claim custom
    // Aqui usamos uma lógica simples: email contém "operador"
    final isOperador = user?.email?.contains('operador') ?? false;

    if (isOperador) {
      return const PainelOperador();
    }
    return const PainelMotorista();
  }
}