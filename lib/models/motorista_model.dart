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

  factory MotoristaModel.fromMap(Map<String, dynamic> map, String id) {
    return MotoristaModel(
      id: id,
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      emailAcesso: map['emailAcesso'] ?? '',
      veiculosPermitidos: List<String>.from(map['veiculosPermitidos'] ?? []),
      ativo: map['ativo'] ?? true, // <--- NOVO CAMPO AQUI (Se não existir no banco, assume true)
    );
  }
}