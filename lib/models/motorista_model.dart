class MotoristaModel {
  final String id;
  final String nome;
  final String cpf;
  final String emailAcesso;
  final List<String> veiculosPermitidos; // Guarda as placas que ele pode dirigir
  final bool ativo;

  MotoristaModel({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.emailAcesso,
    required this.veiculosPermitidos,
    this.ativo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cpf': cpf,
      'emailAcesso': emailAcesso,
      'veiculosPermitidos': veiculosPermitidos,
      'ativo': ativo,
    };
  }

  factory MotoristaModel.fromFirestore(Map<String, dynamic> dados, String docId) {
    return MotoristaModel(
      id: docId,
      nome: dados['nome'] ?? '',
      cpf: dados['cpf'] ?? '',
      emailAcesso: dados['emailAcesso'] ?? '',
      veiculosPermitidos: List<String>.from(dados['veiculosPermitidos'] ?? []),
      ativo: dados['ativo'] ?? true,
    );
  }
}