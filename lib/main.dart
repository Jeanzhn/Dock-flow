import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

enum UserType { admin, motorista, operador }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DockFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const LoginPage(),
    );
  }
}

// ================= LOGIN =================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  UserType? selectedType;

  void login() {
    if (selectedType == null) return;

    switch (selectedType!) {
      case UserType.admin:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage()));
        break;
      case UserType.motorista:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MotoristaPage()));
        break;
      case UserType.operador:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OperadorPage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A3D62), Color(0xFF3C6382)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Login do Sistema",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  buildOption("Administrador", UserType.admin),
                  buildOption("Motorista", UserType.motorista),
                  buildOption("Operador", UserType.operador),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Entrar"),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildOption(String title, UserType type) {
    return RadioListTile<UserType>(
      value: type,
      groupValue: selectedType,
      onChanged: (value) {
        setState(() => selectedType = value);
      },
      title: Text(title),
    );
  }
}

// ================= ADMIN =================

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Administrador")),
      body: const Center(
        child: Text("Controle total do sistema"),
      ),
    );
  }
}

// ================= MOTORISTA =================

class MotoristaPage extends StatefulWidget {
  const MotoristaPage({super.key});

  @override
  State<MotoristaPage> createState() => _MotoristaPageState();
}

class _MotoristaPageState extends State<MotoristaPage> {
  final TextEditingController placaController = TextEditingController();
  final TextEditingController modeloController = TextEditingController();
  
  String locationText = "Aguardando captura...";
  Position? currentPosition;
  bool isLoading = false; // Para mostrar a bolinha girando enquanto busca o GPS

  @override
  void dispose() {
    placaController.dispose();
    modeloController.dispose();
    super.dispose();
  }

  Future<void> getLocation() async {
    setState(() {
      isLoading = true;
      locationText = "Buscando satélites...";
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        isLoading = false;
        locationText = "Ative o GPS do tablet!";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isLoading = false;
          locationText = "Permissão negada";
        });
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentPosition = position;
      locationText = "Posição Confirmada!";
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Painel do Motorista")),
      body: Column(
        children: [
          // PARTE SUPERIOR: Formulário
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: placaController,
                  decoration: const InputDecoration(labelText: "Placa do Veículo"),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : getLocation,
                  icon: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.satellite_alt),
                  label: Text(isLoading ? "Localizando..." : "Capturar Minha Posição"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          
          // PARTE INFERIOR: O Mapa Dinâmico
          Expanded(
            child: currentPosition == null
                ? Center(
                    child: Text(
                      locationText,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      // Centraliza o mapa exatamente onde o motorista está
                      initialCenter: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                      initialZoom: 16.0, // Zoom nível rua
                      
                      // ==========================================
                      // CORREÇÃO: Evita o travamento do Scroll no Web/Windows
                      // ==========================================
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom,
                      ),
                    ),
                    children: [
                      // Desenha as ruas (Usando OpenStreetMap gratuito)
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.dockflow.app',
                      ),
                      // Desenha o pino do caminhão
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.local_shipping, // Ícone de caminhão
                              color: Colors.red,
                              size: 45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          
          // BOTÃO DE ENVIO
          if (currentPosition != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  print("Enviando para backend/local -> Placa: ${placaController.text} | Lat: ${currentPosition!.latitude} | Lng: ${currentPosition!.longitude}");
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirmar e Avisar Pátio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

// ================= OPERADOR =================

class OperadorPage extends StatelessWidget {
  const OperadorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Operador")),
      body: const Center(
        child: Text("Gerenciar fila e chamadas"),
      ),
    );
  }
}