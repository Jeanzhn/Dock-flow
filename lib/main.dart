import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MeuAppLogistico());
}

class MeuAppLogistico extends StatelessWidget {
  const MeuAppLogistico({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Fila - Docas',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TelaSelecaoPerfil(),
    );
  }
}

class TelaSelecaoPerfil extends StatelessWidget {
  const TelaSelecaoPerfil({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecione seu Perfil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaChefe()),
              ),
              child: const Text('Entrar como OPERADOR / CHEFE'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaMotorista()),
              ),
              child: const Text('Entrar como MOTORISTA'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TELA DO OPERADOR / CHEFE (Consome a fila_descarga ordenando por dh_passagem_prf)
// ============================================================================
class TelaChefe extends StatelessWidget {
  const TelaChefe({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Operacional - Fila'),
        backgroundColor: Colors.blueGrey,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Reflete o INDEX composto do MySQL: dh_passagem_prf ASC e is_impossibilitado
        stream: FirebaseFirestore.instance
            .collection('fila_descarga')
            .where('is_impossibilitado', isEqualTo: false)
            .where('dh_chamada', isNull: true)
            .orderBy('dh_passagem_prf', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar a fila: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final filaDocs = snapshot.data!.docs;

          if (filaDocs.isEmpty) {
            return const Center(child: Text('Nenhum veículo aguardando na fila.'));
          }

          return ListView.builder(
            itemCount: filaDocs.length,
            itemBuilder: (context, index) {
              var itemFila = filaDocs[index];
              var dados = itemFila.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(dados['nome_motorista'] ?? 'Motorista Não Identificado'),
                  subtitle: Text('ID Ordem: ${dados['id_ordem']}'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      // Transação simulando o UPDATE do SQL em cascata ou paralelo
                      String idOrdem = dados['id_ordem'];
                      String idOperadorLogado = "OPERADOR_EXEMPLO_ID"; 

                      // 1. Atualiza o status na tabela de Filas
                      await FirebaseFirestore.instance
                          .collection('fila_descarga')
                          .doc(itemFila.id)
                          .update({
                        'dh_chamada': FieldValue.serverTimestamp(),
                        'id_operador': idOperadorLogado,
                      });

                      // 2. Atualiza o status na tabela de Ordens de Descarga
                      await FirebaseFirestore.instance
                          .collection('ordens_descarga')
                          .doc(idOrdem)
                          .update({'status_operacional': 'CHAMADO'});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Chamar'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// TELA DO MOTORISTA (Gera Ordem de Descarga e Entra na Fila)
// ============================================================================
class TelaMotorista extends StatefulWidget {
  const TelaMotorista({Key? key}) : super(key: key);

  @override
  _TelaMotoristaState createState() => _TelaMotoristaState();
} 

class _TelaMotoristaState extends State<TelaMotorista> {
  bool _enviando = false;
  String _status = 'Pendente';
  
  // UID fixo de teste representando o Motorista logado
  final String _idMotoristaLogado = "USER_MOTO_VAL_123"; 
  final String _idVeiculoLogado = "VEICULO_VAL_ABC"; 
  String? _idOrdemCriada;

  Future<void> _darEntradaNaFila() async {
    setState(() {
      _enviando = true;
      _status = 'Obtendo dados operacionais...';
    });

    try {
      // 1. Garante permissões de localização (Simulando passagem no posto/PRF)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS desativado.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Sem permissão de GPS.');
      }

      // 2. Criar registro na coleção 'ordens_descarga' (Equivalente ao INSERT INTO ordens_descarga)
      DocumentReference novaOrdemRef = await FirebaseFirestore.instance
          .collection('ordens_descarga')
          .add({
        'id_motorista': _idMotoristaLogado,
        'id_veiculo': _idVeiculoLogado,
        'status_operacional': 'NA_FILA',
        'data_criacao': FieldValue.serverTimestamp(),
      });

      _idOrdemCriada = novaOrdemRef.id;

      // 3. Inserir na coleção 'fila_descarga' usando o ID da ordem como chave (Equivalente ao INSERT INTO fila_descarga)
      await FirebaseFirestore.instance
          .collection('fila_descarga')
          .doc(_idOrdemCriada)
          .set({
        'id_ordem': _idOrdemCriada,
        'id_operador': null,
        'nome_motorista': 'Motorista Teste Região',
        'dh_passagem_prf': FieldValue.serverTimestamp(), // Marcação de tempo da entrada
        'is_impossibilitado': false,
        'dh_chamada': null,
      });

      setState(() {
        _status = 'Confirmado na Fila de Descarga!';
      });

      _iniciarEscutaDeChamada();

    } catch (e) {
      setState(() {
        _status = 'Erro na operação: $e';
      });
    } finally {
      setState(() {
        _enviando = false;
      });
    }
  }

  void _iniciarEscutaDeChamada() {
    if (_idOrdemCriada == null) return;

    FirebaseFirestore.instance
        .collection('fila_descarga')
        .doc(_idOrdemCriada)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
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
          title: const Text('Painel de Convocação', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('Sua ordem de descarga foi chamada! Dirija-se imediatamente à doca demarcada.'),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Confirmar Ciente'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
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
      appBar: AppBar(title: const Text('Área do Motorista')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _enviando ? null : _darEntradaNaFila,
                icon: _enviando 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.local_shipping),
                label: const Text('Dar Entrada via PRF e Entrar na Fila'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}