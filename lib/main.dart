import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart'; // Necessário para o Radar em background
import 'package:shared_preferences/shared_preferences.dart'; // Necessário para recuperar a viagem

import 'screens/auth/login_screen.dart';
import 'screens/motorista/painel_motorista.dart';
import 'screens/operador/painel_operador.dart';
import 'screens/administrativo/painel_admin.dart';
import 'services/sync_service.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // O Isolate de background precisa da sua própria conexão com o Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: dev.DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    // 1. Executa a sincronização offline
    await SyncService.sincronizarDadosPendentes();

    // 2. Aciona o Radar Silencioso (Geofencing via GPS)
    try {
      Position posicaoAtual = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      final prefs = await SharedPreferences.getInstance();
      final viagemId = prefs.getString('viagem_atual_id'); 
      
      // Se houver uma viagem em andamento salva no aparelho, passa no radar
      if (viagemId != null && viagemId.isNotEmpty) {
        await SyncService.verificarGeofenceDoca(
          viagemId, 
          posicaoAtual.latitude, 
          posicaoAtual.longitude
        );
      }
    } catch (e) {
      debugPrint('Erro ao acionar o GPS no background: $e');
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('==== 1. INICIANDO MAIN ====');

  try {
    if (Firebase.apps.isEmpty) {
      debugPrint('==== 2. INICIANDO FIREBASE ====');
      const String env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
      await Firebase.initializeApp(
        options: env == 'prod'
            ? prod.DefaultFirebaseOptions.currentPlatform
            : dev.DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('==== 3. FIREBASE PRONTO ====');
    }

    debugPrint('==== 4. INICIANDO WORKMANAGER ====');
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    debugPrint('==== 5. WORKMANAGER PRONTO ====');

    debugPrint('==== 6. REGISTRANDO TAREFAS ====');
    Workmanager().registerPeriodicTask(
      "sync_task_1", 
      "syncLogsOffline", 
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
    debugPrint('==== 7. TAREFAS REGISTRADAS ====');

  } catch (e) {
    debugPrint('==== ERRO CRÍTICO NO MAIN: $e ====');
  }

  debugPrint('==== 8. DESENHANDO A TELA (RUNAPP) ====');
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