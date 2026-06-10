import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  static const String _logKey = 'offline_logs';

  // 1. Grava a ação no celular do motorista (Consumo de memória quase zero)
  static Future<void> salvarLogLocal(String viagemId, String acao) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_logKey) ?? [];
    
    final novoLog = jsonEncode({
      'viagemId': viagemId,
      'acao': acao,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    logs.add(novoLog);
    await prefs.setStringList(_logKey, logs);
  }

  // 2. Tenta enviar para a nuvem
  static Future<void> sincronizarDadosPendentes() async {
    var conectividade = await Connectivity().checkConnectivity();
    if (conectividade == ConnectivityResult.none) return; // Sem internet, aborta silenciosamente

    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_logKey) ?? [];
    if (logs.isEmpty) return;

    final db = FirebaseFirestore.instance;
    List<String> logsRestantes = [];

    for (String logStr in logs) {
      try {
        final log = jsonDecode(logStr);
        final id = log['viagemId'];
        final acao = log['acao'];
        final time = DateTime.parse(log['timestamp']);

        // Processa a ação retroativa para o Firebase
        if (acao == 'CARREGADO') {
          await db.collection('viagens').doc(id).update({'statusOperacional': 'CARREGADO', 'dhCarregamento': Timestamp.fromDate(time)});
        } else if (acao == 'SAIU_TRIAGEM') {
          // Opção B: Entra na fila com o horário que SAIU da PRF
          await db.collection('viagens').doc(id).update({
            'statusOperacional': 'NA_FILA', 
            'dhEntradaFila': Timestamp.fromDate(time),
            'posicaoFila': time.millisecondsSinceEpoch
          });
        } else if (acao == 'CHEGOU_DOCA') {
          await db.collection('viagens').doc(id).update({'statusOperacional': 'CHEGOU_DOCA'});
        }
      } catch (e) {
        logsRestantes.add(logStr); // Se deu erro neste log específico, mantém na memória
      }
    }
    // Limpa a memória do celular
    await prefs.setStringList(_logKey, logsRestantes);
  }
}