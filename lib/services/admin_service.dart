import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/motorista_model.dart';
import '../models/veiculo_model.dart';
import '../models/ponto_controle_model.dart';
class AdminService {
  final _db = FirebaseFirestore.instance;

  // ==========================================
  // GESTÃO DE VEÍCULOS
  // ==========================================
  Future<void> adicionarVeiculo(String placa) async {
    final placaLimpa = placa.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    await _db.collection('veiculos').doc(placaLimpa).set({
      'placa': placaLimpa,
      'ativo': true,
      'dhCriacao': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<VeiculoModel>> streamVeiculos() {
    return _db.collection('veiculos').snapshots().map((s) => 
      s.docs.map((d) => VeiculoModel.fromFirestore(d.data(), d.id)).toList()
    );
  }
  
  // 1. Editar Placa do Veículo (Atualiza também a permissão dos motoristas)
  Future<void> editarVeiculo(String placaAntiga, String novaPlaca) async {
    final db = FirebaseFirestore.instance;
    
    // Atualiza a placa na coleção de veículos
    final veiculoQuery = await db.collection('veiculos').where('placa', isEqualTo: placaAntiga).get();
    if (veiculoQuery.docs.isNotEmpty) {
      await veiculoQuery.docs.first.reference.update({'placa': novaPlaca});
    }

    // Varre os motoristas e atualiza a placa antiga pela nova na lista de permitidos
    final motoristasQuery = await db.collection('motoristas').where('veiculosPermitidos', arrayContains: placaAntiga).get();
    for (var doc in motoristasQuery.docs) {
      List<dynamic> veiculos = doc.data()['veiculosPermitidos'] ?? [];
      veiculos.remove(placaAntiga);
      veiculos.add(novaPlaca);
      await doc.reference.update({'veiculosPermitidos': veiculos});
    }
  }

  // 2. Editar Informações do Motorista (Nome e CPF)
  Future<void> editarInfoMotorista(String id, String novoNome, String novoCpf) async {
    await FirebaseFirestore.instance.collection('motoristas').doc(id).update({
      'nome': novoNome,
      'cpf': novoCpf,
    });
  }

  // 3. Remover Motorista
  Future<void> alternarAcessoMotorista(String id, bool statusAtual) async {
    // Se ele está ativo (true), vai virar inativo (false) e vice-versa.
    await FirebaseFirestore.instance.collection('motoristas').doc(id).update({
      'ativo': !statusAtual,
    });
  }

  Future<void> criarMotorista({
    required String nome,
    required String cpf,
    required List<String> veiculosIniciais,
  }) async {

    final cpfLimpo = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpfLimpo.length != 11) throw Exception("CPF inválido. Digite os 11 números.");
    final ultimos4 = cpfLimpo.substring(7);

    // 2. Extrai o primeiro nome, converte para minúsculo e remove acentos
    String primeiroNome = nome.trim().split(' ')[0].toLowerCase();
    primeiroNome = primeiroNome
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éèê]'), 'e')
        .replaceAll(RegExp(r'[íìî]'), 'i')
        .replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úùû]'), 'u')
        .replaceAll(RegExp(r'ç'), 'c');

    final emailGerado = '$primeiroNome$ultimos4@dockflow.com'; 
    final senhaGerada = '2026$ultimos4';
    // 2. Cria o usuário no Firebase Auth SEM deslogar o Admin
    FirebaseApp appSecundario = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );
    
    try {
      await FirebaseAuth.instanceFor(app: appSecundario)
          .createUserWithEmailAndPassword(email: emailGerado, password: senhaGerada);
    } catch (e) {
      // Ignora erro se o usuário já existir, apenas atualiza o banco de dados abaixo
    } finally {
      await appSecundario.delete(); // Destrói a instância secundária
    }

    // 3. Salva o perfil completo no Firestore
    final docRef = _db.collection('motoristas').doc();
    final novoMotorista = MotoristaModel(
      id: docRef.id,
      nome: nome,
      cpf: cpfLimpo,
      emailAcesso: emailGerado,
      veiculosPermitidos: veiculosIniciais,
    );

    await docRef.set(novoMotorista.toMap());
  }

  // Atualiza as placas que o motorista tem permissão para dirigir
  Future<void> atualizarPermissoesVeiculos(String motoristaId, List<String> novasPlacas) async {
    await _db.collection('motoristas').doc(motoristaId).update({
      'veiculosPermitidos': novasPlacas,
    });
  }

  Future<void> removerVeiculo(String placa) async {
      await _db.collection('veiculos').doc(placa).delete();
    }

  Stream<List<MotoristaModel>> streamMotoristas() {
    return _db.collection('motoristas').snapshots().map((s) => 
      s.docs.map((d) => MotoristaModel.fromMap(d.data(), d.id)).toList()
    );
  }

  Future<void> adicionarPontoControle(PontoControleModel ponto) async {
    final docRef = _db.collection('pontos_controle').doc();
    final novoPonto = PontoControleModel(
      id: docRef.id,
      nome: ponto.nome,
      lat: ponto.lat,
      lng: ponto.lng,
      raioMetros: ponto.raioMetros,
      tipoAcao: ponto.tipoAcao,
    );
    await docRef.set(novoPonto.toMap());
  }

  Stream<List<PontoControleModel>> streamPontosControle() {
    return _db.collection('pontos_controle').snapshots().map((s) => 
      s.docs.map((d) => PontoControleModel.fromFirestore(d.data(), d.id)).toList()
    );
  }

  Future<void> removerPontoControle(String id) async {
    await _db.collection('pontos_controle').doc(id).delete();
  }

  Future<void> atualizarRaioPontoControle(String id, double novoRaio) async {
    await _db.collection('pontos_controle').doc(id).update({
      'raioMetros': novoRaio,
    });
  }

  Future<void> atualizarPosicaoPonto(String id, double lat, double lng) async {
    await _db.collection('pontos_controle').doc(id).update({
      'lat': lat,
      'lng': lng,
    });
  }
}
