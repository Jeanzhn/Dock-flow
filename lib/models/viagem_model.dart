import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusOperacional { PENDENTE, CARREGADO, NA_FILA, CHAMADO, EM_DESCARGA, QUEBRADO, CONCLUIDO }

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
  final DateTime? dhChegadaDoca;
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
    this.dhChegadaDoca,
    this.dhChamada,
    this.dhConclusao,
    this.posicaoFila,
    this.isImpossibilitado = false,
  });

  // Converte o modelo em um Mapa para salvar no Firebase usando APENAS CamelCase
  Map<String, dynamic> toMap() {
    return {
      'id': id, 
      'motoristaEmail': motoristaEmail,
      'motoristaNome': motoristaNome,
      'placaVeiculo': placaVeiculo,
      'origem': origem,
      'destino': destino,
      'tipoCarga': tipoCarga,
      'statusOperacional': statusOperacional.name, // Nome unificado
      'dhInicio': dhInicio != null ? Timestamp.fromDate(dhInicio!) : null,
      'dhCarregamento': dhCarregamento != null ? Timestamp.fromDate(dhCarregamento!) : null,
      'dhEntradaFila': dhEntradaFila != null ? Timestamp.fromDate(dhEntradaFila!) : null,
      'dhChegadaDoca': dhChegadaDoca != null ? Timestamp.fromDate(dhChegadaDoca!) : null,
      'dhChamada': dhChamada != null ? Timestamp.fromDate(dhChamada!) : null,
      'dhConclusao': dhConclusao != null ? Timestamp.fromDate(dhConclusao!) : null,
      'posicaoFila': posicaoFila, // Unificado
      'isImpossibilitado': isImpossibilitado,
    };
  }

  // Reconstrutor Unificado: Converte os dados do Firebase usando APENAS CamelCase
  factory ViagemModel.fromFirestore(DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>? ?? {};

    // Função auxiliar limpa para conversão de Timestamps
    DateTime? lerData(String chave) {
      if (dados[chave] is Timestamp) {
        return (dados[chave] as Timestamp).toDate();
      }
      return null;
    }

    return ViagemModel(
      id: dados['id'] ?? doc.id,
      motoristaEmail: dados['motoristaEmail'] ?? '',
      motoristaNome: dados['motoristaNome'] ?? '',
      placaVeiculo: dados['placaVeiculo'] ?? '',
      origem: dados['origem'] ?? '',
      destino: dados['destino'] ?? 'Santana-AP',
      tipoCarga: dados['tipoCarga'] ?? '',
      statusOperacional: StatusOperacional.values.firstWhere(
        (e) => e.name == (dados['statusOperacional'] ?? 'PENDENTE'),
        orElse: () => StatusOperacional.PENDENTE,
      ),
      dhInicio: lerData('dhInicio'),
      dhCarregamento: lerData('dhCarregamento'),
      dhEntradaFila: lerData('dhEntradaFila'),
      dhChegadaDoca: lerData('dhChegadaDoca'),
      dhChamada: lerData('dhChamada'),
      dhConclusao: lerData('dhConclusao'),
      posicaoFila: dados['posicaoFila'] as int?,
      isImpossibilitado: dados['isImpossibilitado'] ?? false,
    );
  }
}