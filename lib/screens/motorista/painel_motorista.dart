import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../auth/login_screen.dart';
import '../../services/auth_service.dart';

class PainelMotoristaScreen extends StatefulWidget {
  const PainelMotoristaScreen({Key? key}) : super(key: key);

  @override
  State<PainelMotoristaScreen> createState() => _PainelMotoristaScreenState();
}

class _PainelMotoristaScreenState extends State<PainelMotoristaScreen> {
  bool _enviando = false;
  String _status = 'Aguardando ação...';
  String? _idOrdemCriada;

  Future<void> _darEntradaNaFila() async {
    setState(() {
      _enviando = true;
      _status = 'Verificando GPS...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS desativado.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Sem permissão de GPS.');
      }

      setState(() => _status = 'Registrando na fila...');

      // Criando registro no Firebase
      DocumentReference novaOrdemRef = await FirebaseFirestore.instance.collection('fila_descarga').add({
        'id_ordem': 'ORDEM_${DateTime.now().millisecondsSinceEpoch}',
        'nome_motorista': 'Motorista Teste',
        'dh_passagem_prf': FieldValue.serverTimestamp(),
        'is_impossibilitado': false,
        'dh_chamada': null,
      });

      _idOrdemCriada = novaOrdemRef.id;
      setState(() => _status = 'Confirmado na Fila! Aguarde ser chamado.');
      _iniciarEscutaDeChamada();

    } catch (e) {
      setState(() => _status = 'Erro: $e');
    } finally {
      setState(() => _enviando = false);
    }
  }

  void _iniciarEscutaDeChamada() {
    if (_idOrdemCriada == null) return;

    FirebaseFirestore.instance.collection('fila_descarga').doc(_idOrdemCriada).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var dados = snapshot.data() as Map<String, dynamic>;
        if (dados['dh_chamada'] != null) {
          _mostrarPopupSuaVez();
        }
      }
    });
  }

  void _mostrarPopupSuaVez() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🚨 ATENÇÃO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24)),
          content: const Text('SUA VEZ!\nDirija-se imediatamente à doca demarcada.', style: TextStyle(fontSize: 18)),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('CONFIRMAR CIENTE', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _status = 'Ordem Concluída. Dirigindo-se à doca.');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App do Motorista'),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().deslogar();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_shipping, size: 100, color: Colors.grey),
              const SizedBox(height: 20),
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              SizedBox(
                height: 60,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviando || _idOrdemCriada != null ? null : _darEntradaNaFila,
                  icon: _enviando 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Icon(Icons.login),
                  label: const Text('ENTRAR NA FILA (PRF)', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}