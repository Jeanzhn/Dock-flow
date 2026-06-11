import 'dart:convert';
import 'package:flutter/foundation.dart'; // Necessário para o debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart'; // Necessário para calcular a distância

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

    debugPrint('💾 DEBUG OFFLINE: Ação "$acao" foi gravada fisicamente na memória do telemóvel! Total na fila: ${logs.length}');
  }

  // 2. Tenta enviar para a nuvem com BLINDAGEM de fluxo
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
          await db.collection('viagens').doc(id).update({
            'status_operacional': 'CARREGADO', 
            'dhCarregamento': Timestamp.fromDate(time)
          });
          
        } else if (acao == 'SAIU_TRIAGEM') {
          await db.collection('viagens').doc(id).update({
            'status_operacional': 'NA_FILA', 
            'dhEntradaFila': Timestamp.fromDate(time),
            'posicaoFila': time.millisecondsSinceEpoch
          });
          
        } else if (acao == 'CHEGOU_DOCA') {
          // A MÁGICA DE PROTEÇÃO OFFLINE AQUI:
          final docAtual = await db.collection('viagens').doc(id).get();
          final statusBanco = docAtual.data()?['status_operacional'];

          if (statusBanco == 'CHAMADO') {
            await db.collection('viagens').doc(id).update({
              'status_operacional': 'CHEGOU_DOCA'
            });
          } else {
            // Se sincronizou "CHEGOU_DOCA" mas não estava "CHAMADO", pegamos no flagra!
            await db.collection('viagens').doc(id).update({
              'alertaInfracao': 'Chegou na doca sem ser chamado (Offline Sync)',
              'dhInfracao': Timestamp.fromDate(time),
            });
          }
        }
      } catch (e) {
        logsRestantes.add(logStr); // Se deu erro neste log específico, mantém na memória
      }
    }
    // Limpa a memória do celular
    await prefs.setStringList(_logKey, logsRestantes);
  }

  // 3. Radar Silencioso (Chamado periodicamente pelo WorkManager)
  static Future<void> verificarGeofenceDoca(String viagemId, double latAtual, double lonAtual) async {
    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('viagens').doc(viagemId);
      final doc = await docRef.get();
      
      if (!doc.exists) return;
      
      final statusAtual = doc.data()?['status_operacional'];

      // Coordenadas das Docas em Santana (Ajuste para o local exato do porto)
      const double docaLat = -0.0583; 
      const double docaLon = -51.1717; 
      
      final double distanciaAteDoca = Geolocator.distanceBetween(
        latAtual, lonAtual, docaLat, docaLon
      );

      // Entrou no raio de 300 metros?
      if (distanciaAteDoca <= 300) { 
        
        if (statusAtual == 'CHAMADO') {
          // Fluxo respeitado
          await docRef.update({'status_operacional': 'CHEGOU_DOCA'});
          debugPrint('Radar: Motorista chegou na doca.');
          
        } else if (statusAtual == 'NA_FILA') {
          // Furo de fila detectado via GPS!
          await docRef.update({
            'alertaInfracao': 'Aproximação não autorizada na doca via GPS',
            'dhInfracao': FieldValue.serverTimestamp(),
          });
          debugPrint('Radar ALERTA: Caminhão invadiu a doca!');
        }
      }
    } catch (e) {
      debugPrint('Erro no radar da doca: $e');
    }
  }
}