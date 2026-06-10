class PontoControleModel {
  final String id;
  final String nome;
  final double lat;
  final double lng;
  final double raioMetros;
  final String tipoAcao; // 'CARREGAMENTO', 'FILA', ou 'DOCA'

  PontoControleModel({
    required this.id,
    required this.nome,
    required this.lat,
    required this.lng,
    required this.raioMetros,
    required this.tipoAcao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'lat': lat,
      'lng': lng,
      'raioMetros': raioMetros,
      'tipoAcao': tipoAcao,
    };
  }

  factory PontoControleModel.fromFirestore(Map<String, dynamic> dados, String docId) {
    return PontoControleModel(
      id: docId,
      nome: dados['nome'] ?? '',
      lat: (dados['lat'] ?? 0.0).toDouble(),
      lng: (dados['lng'] ?? 0.0).toDouble(),
      raioMetros: (dados['raioMetros'] ?? 50.0).toDouble(),
      tipoAcao: dados['tipoAcao'] ?? 'FILA',
    );
  }
} 