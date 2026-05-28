import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_screen.dart';
import '../../services/auth_service.dart';

class PainelOperadorScreen extends StatelessWidget {
  const PainelOperadorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Operacional - Docas'),
        backgroundColor: Colors.blueGrey,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fila_descarga')
            .where('is_impossibilitado', isEqualTo: false)
            .where('dh_chamada', isNull: true)
            .orderBy('dh_passagem_prf', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final filaDocs = snapshot.data!.docs;

          if (filaDocs.isEmpty) return const Center(child: Text('Nenhum veículo aguardando na fila.', style: TextStyle(fontSize: 18)));

          return ListView.builder(
            itemCount: filaDocs.length,
            itemBuilder: (context, index) {
              var dados = filaDocs[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blueGrey, child: Text('${index + 1}', style: const TextStyle(color: Colors.white))),
                  title: Text(dados['nome_motorista'] ?? 'Motorista Não Identificado', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID Ordem: ${dados['id_ordem']}'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      // Chama o motorista via Firebase
                      await FirebaseFirestore.instance.collection('fila_descarga').doc(filaDocs[index].id).update({
                        'dh_chamada': FieldValue.serverTimestamp(),
                        'id_operador': 'OPERADOR_LOGADO',
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('CHAMAR', style: TextStyle(color: Colors.white)),
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