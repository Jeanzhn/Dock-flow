
class VeiculoModel {
  final String id;
  final String placa;
  final bool ativo;

  VeiculoModel({
    required this.id,
    required this.placa,
    this.ativo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placa': placa,
      'ativo': ativo,
    };
  }

  factory VeiculoModel.fromFirestore(Map<String, dynamic> dados, String docId) {
    return VeiculoModel(
      id: docId,
      placa: dados['placa'] ?? '',
      ativo: dados['ativo'] ?? true,
    );
  }
}