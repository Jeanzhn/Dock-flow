import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusOperacional { PENDENTE, CARREGADO, NA_FILA, CHAMADO, QUEBRADO, CONCLUIDO }

class ViagemModel {
  final String id;
  final String motoristaEmail;
  final String motoristaNome;
  final String placaVeiculo;
  final String origem;
  final String destino;
  final String tipoCarga;
  final StatusOperacional statusOperacional;
  final DateTime? dhInicio;
  final DateTime? dhCarregamento;
  final DateTime? dhEntradaFila;
  final DateTime? dhChamada;
  final DateTime? dhConclusao;
  final int? posicaoFila;
  final bool isImpossibilitado;

  ViagemModel({
    required this.id,
    required this.motoristaEmail,
    required this.motoristaNome,
    required this.placaVeiculo,
    required this.origem,
    required this.destino,
    required this.tipoCarga,
    this.statusOperacional = StatusOperacional.PENDENTE,
    this.dhInicio,
    this.dhCarregamento,
    this.dhEntradaFila,
    this.dhChamada,
    this.dhConclusao,
    this.posicaoFila,
    this.isImpossibilitado = false,
  });

  // Converte o modelo em um Mapa para salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Garante que o ID vá para o documento
      'motoristaEmail': motoristaEmail,
      'motoristaNome': motoristaNome,
      'placaVeiculo': placaVeiculo,
      'origem': origem,
      'destino': destino,
      'tipoCarga': tipoCarga,
      'statusOperacional': statusOperacional.name,
      'dhInicio': dhInicio != null ? Timestamp.fromDate(dhInicio!) : null,
      'dhCarregamento': dhCarregamento != null ? Timestamp.fromDate(dhCarregamento!) : null,
      'dhEntradaFila': dhEntradaFila != null ? Timestamp.fromDate(dhEntradaFila!) : null,
      'dhChamada': dhChamada != null ? Timestamp.fromDate(dhChamada!) : null,
      'dhConclusao': dhConclusao != null ? Timestamp.fromDate(dhConclusao!) : null,
      'posicaoFila': posicaoFila,
      'isImpossibilitado': isImpossibilitado,
    };
  }

  // RECONSTRUTOR BLINDADO: Converte os dados que vêm do Firebase de volta para o app
  factory ViagemModel.fromFirestore(DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>? ?? {};

    // Função auxiliar segura para ler datas em qualquer formato de carimbo do Firebase
    DateTime? lerData(String chave) {
      if (dados[chave] == null) return null;
      if (dados[chave] is Timestamp) return (dados[chave] as Timestamp).toDate();
      return null;
    }

    // Lê o status tratando variações de maiúsculas, minúsculas ou underlines dos testes antigos
    StatusOperacional converterStatus(String statusBruto) {
      final limpo = statusBruto.toUpperCase().replaceAll('_', '');
      if (limpo.contains('CARREGADO')) return StatusOperacional.CARREGADO;
      if (limpo.contains('FILA')) return StatusOperacional.NA_FILA;
      if (limpo.contains('CHAMADO')) return StatusOperacional.CHAMADO;
      if (limpo.contains('QUEBRADO')) return StatusOperacional.QUEBRADO;
      if (limpo.contains('CONCLUIDO')) return StatusOperacional.CONCLUIDO;
      return StatusOperacional.PENDENTE;
    }

    // Pega o status bruto da string salva na nuvem
    final statusTexto = dados['statusOperacional'] ?? dados['status_operacional'] ?? 'PENDENTE';

    return ViagemModel(
      id: doc.id,
      motoristaEmail: dados['motoristaEmail'] ?? dados['motorista_email'] ?? '',
      motoristaNome: dados['motoristaNome'] ?? dados['motorista_name'] ?? '',
      placaVeiculo: dados['placaVeiculo'] ?? dados['placa_veiculo'] ?? '',
      origem: dados['origem'] ?? '',
      destino: dados['destino'] ?? 'Santana-AP',
      tipoCarga: dados['tipoCarga'] ?? dados['tipo_carga'] ?? '',
      statusOperacional: converterStatus(statusTexto.toString()),
      dhInicio: lerData('dhInicio') ?? lerData('dh_inicio'),
      dhCarregamento: lerData('dhCarregamento') ?? lerData('dh_carregamento'),
      dhEntradaFila: lerData('dhEntradaFila') ?? lerData('dh_entrada_fila'),
      dhChamada: lerData('dhChamada') ?? lerData('dh_chamada'),
      dhConclusao: lerData('dhConclusao') ?? lerData('dh_conclusao'),
      posicaoFila: dados['posicaoFila'] ?? dados['posicao_fila'],
      isImpossibilitado: dados['isImpossibilitado'] ?? dados['is_impossibilitado'] ?? false,
    );
  }
}