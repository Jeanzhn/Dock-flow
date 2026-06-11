import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/viagem_model.dart';

class ViagemService {
  final _col = FirebaseFirestore.instance.collection('viagens');

  // Stream da Fila do Operador: Filtra os motoristas ativos na fila e ordena na memória
  Stream<List<ViagemModel>> streamFila() {
    return _col.snapshots().map((s) {
      if (s.docs.isEmpty) return [];

      final lista = s.docs.map((doc) => ViagemModel.fromFirestore(doc)).where((v) {
        final status = v.statusOperacional.toString().split('.').last.toUpperCase();
        return status == 'NA_FILA' || status == 'CHAMADO';
      }).toList();

      // Ordenação FIFO estável
      lista.sort((a, b) => (a.posicaoFila ?? 0).compareTo(b.posicaoFila ?? 0));
      return lista;
    });
  }

  // Stream de todas as viagens que não foram finalizadas
  Stream<List<ViagemModel>> streamTodasAtivas() {
    return _col.snapshots().map((s) {
      return s.docs.map((doc) => ViagemModel.fromFirestore(doc)).where((v) {
        final status = v.statusOperacional.toString().split('.').last.toUpperCase();
        return status != 'CONCLUIDO';
      }).toList();
    });
  }

  Stream<List<ViagemModel>> streamTodasViagensOperador() {
    return _col.snapshots().map((s) {
      final lista = s.docs.map((doc) => ViagemModel.fromFirestore(doc)).toList();
      // Ordena na memória para que as viagens mais recentes fiquem no topo da lista
      lista.sort((a, b) => (b.dhInicio ?? DateTime.now()).compareTo(a.dhInicio ?? DateTime.now()));
      return lista;
    });
  }

  Stream<ViagemModel?> streamViagemAtiva(String email) {
    return _col.snapshots().map((s) {
      if (s.docs.isEmpty) return null;

      try {
        // Faz uma busca minuciosa por qualquer documento ativo que pertença a este e-mail
        final docAtivo = s.docs.firstWhere((doc) {
          final dados = doc.data() as Map<String, dynamic>? ?? {};
          
          // Pega o e-mail testando TODAS as variações de chaves possíveis
          final emailDoBanco = dados['motoristaEmail'] ?? 
                               dados['motorista_email'] ?? 
                               dados['email'] ?? '';

          // Pega o status do Firebase
          final statusTexto = dados['status_operacional'] ?? 'PENDENTE';
                              
          final statusLimpo = statusTexto.toString().toUpperCase().replaceAll('_', '');

          // O documento serve se for do motorista atual E não estiver CONCLUIDO
          return emailDoBanco.toString().trim().toLowerCase() == email.trim().toLowerCase() && 
                 statusLimpo != 'CONCLUIDO';
        });

        // Retorna o documento convertido de forma limpa
        return ViagemModel.fromFirestore(docAtivo);
      } catch (e) {
        // Se não encontrar nenhuma viagem em andamento, abre a tela de nova viagem
        return null;
      }
    });
  }

  // Cria a nova viagem no banco
  Future<void> criarViagem(ViagemModel viagem) async {
    final docRef = _col.doc(); // Cria uma referência vazia para gerar o ID primeiro
    
    final viagemComId = ViagemModel(
      id: docRef.id, // Injeta o ID gerado
      motoristaEmail: viagem.motoristaEmail,
      motoristaNome: viagem.motoristaNome,
      placaVeiculo: viagem.placaVeiculo,
      origem: viagem.origem,
      destino: viagem.destino,
      tipoCarga: viagem.tipoCarga,
      statusOperacional: viagem.statusOperacional,
      dhInicio: viagem.dhInicio,
    );

    await docRef.set(viagemComId.toMap()); // Salva usando o .set() com o ID fixado
  }

  // Atualiza Status Genérico
  Future<void> atualizarStatus(
    String id,
    StatusOperacional novoStatus, {
    Map<String, dynamic> extras = const {},
  }) async {
    final Map<String, dynamic> dadosParaAtualizar = Map.from(extras);

    dadosParaAtualizar.forEach((chave, valor) {
      if (valor is DateTime) {
        dadosParaAtualizar[chave] = Timestamp.fromDate(valor);
      }
    });

    await _col.doc(id).update({
      'status_operacional': novoStatus.name, // Usa apenas a chave em snake_case correta
      ...dadosParaAtualizar,
    });
  }

  // Coloca o motorista na fila de espera instantaneamente
  Future<void> entrarNaFila(String viagemId) async {
    final now = DateTime.now();
    await _col.doc(viagemId).update({
      'status_operacional': StatusOperacional.NA_FILA.name,
      'dhEntradaFila': Timestamp.fromDate(now),
      'posicaoFila': now.millisecondsSinceEpoch,
    });
  }

  // Operador chama o motorista para a doca
  Future<void> chamarMotorista(String viagemId) async {
    await _col.doc(viagemId).update({
      'status_operacional': StatusOperacional.CHAMADO.name,
      'dhChamada': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Reporta problema mecânico
  Future<void> reportarQuebra(String viagemId) async {
    await _col.doc(viagemId).update({
      'status_operacional': StatusOperacional.QUEBRADO.name,
      'isImpossibilitado': true,
    });
  }

  // Finaliza a manutenção e retorna à fila
  Future<void> consertarVeiculo(String viagemId) async {
    await _col.doc(viagemId).update({
      'status_operacional': StatusOperacional.NA_FILA.name,
      'isImpossibilitado': false,
    });
  }

  // Busca o histórico real de todas as viagens CONCLUÍDAS
  Stream<List<ViagemModel>> streamHistoricoConcluido(String email) {
    return _col.snapshots().map((s) {
      if (s.docs.isEmpty) return [];

      final lista = s.docs.map((doc) => ViagemModel.fromFirestore(doc)).where((v) {
        final emailDoBanco = v.motoristaEmail.trim().toLowerCase();
        final statusStr = v.statusOperacional.toString().split('.').last.toUpperCase();
        
        return emailDoBanco == email.trim().toLowerCase() && statusStr == 'CONCLUIDO';
      }).toList();

      lista.sort((a, b) {
        final dataA = a.dhConclusao ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dataB = b.dhConclusao ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dataB.compareTo(dataA);
      });

      return lista;
    });
  }
}