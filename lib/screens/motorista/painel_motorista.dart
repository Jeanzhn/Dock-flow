import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dock_flow/screens/auth/login_screen.dart';
import '../../models/viagem_model.dart';
import '../../services/viagem_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/status_badge.dart';

class PainelMotorista extends StatefulWidget {
  const PainelMotorista({super.key});

  @override
  State<PainelMotorista> createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  final _service = ViagemService();
  final _auth = AuthService();
  final _placaCtrl = TextEditingController();
  String? _origemSelecionada;
  String? _tipoCargaSelecionado;
  bool _loading = false;
  
  // Controle de estados de alternância das telas
  bool _exibirFormularioNovaViagem = false;
  bool _modalAberto = false; // Trava de segurança para o pop-up do chamado
  
  // Guarda a referência da viagem concluída para a tela de recibo
  ViagemModel? _ultimaViagemConcluida;

  final _origens = ['Pedra Branca', 'Macapá', 'Laranjal do Jari', 'Oiapoque', 'Porto Grande'];
  final _tiposCarga = ['Minério', 'Grãos', 'Madeira', 'Combustível', 'Container', 'Geral'];

  User get _user => FirebaseAuth.instance.currentUser!;

  @override
  void dispose() {
    _placaCtrl.dispose();
    super.dispose();
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '--/--/-- --:--';
    return DateFormat('dd/05/yy HH:mm').format(data);
  }

  Future<void> _criarViagem() async {
    if (_placaCtrl.text.isEmpty || _origemSelecionada == null || _tipoCargaSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    String placaLimpa = _placaCtrl.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    RegExp regexPlaca = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');

    if (!regexPlaca.hasMatch(placaLimpa)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Placa inválida! Use o formato ABC1234 ou ABC1D23.'), 
          backgroundColor: Colors.red
        ),
      );
      return;
    }
    
    _placaCtrl.text = placaLimpa;
  
    setState(() => _loading = true);
    
    try {
      final viagemExistente = await FirebaseFirestore.instance
          .collection('viagens')
          .where('motoristaEmail', isEqualTo: _user.email!)
          .get();

      if (viagemExistente.docs.isNotEmpty) {
        bool temViagemAtiva = viagemExistente.docs.any((doc) {
          final dados = doc.data();
          final status = dados['statusOperacional'] ?? dados['status_operacional'] ?? '';
          return status != 'CONCLUIDO';
        });

        if (temViagemAtiva) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Bloqueio: Você já possui uma viagem ativa! Conclua a atual antes de iniciar outra.'),
                backgroundColor: Colors.amber,
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }
      }

      await _service.criarViagem(ViagemModel(
        id: '',
        motoristaEmail: _user.email!,
        motoristaNome: _user.displayName ?? _user.email!,
        placaVeiculo: _placaCtrl.text.toUpperCase().trim(),
        origem: _origemSelecionada!,
        destino: 'Santana-AP',
        tipoCarga: _tipoCargaSelecionado!,
        dhInicio: DateTime.now(),
      ));

      _placaCtrl.clear();
      setState(() {
        _origemSelecionada = null;
        _tipoCargaSelecionado = null;
        _exibirFormularioNovaViagem = false;
        _modalAberto = false; 
        _ultimaViagemConcluida = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viagem iniciada com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar viagem: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _executarAcao(ViagemModel viagem, String acao) async {
    setState(() => _loading = true);
    try {
      switch (acao) {
        case 'CARREGADO':
          await _service.atualizarStatus(viagem.id, StatusOperacional.CARREGADO,
              extras: {'dhCarregamento': DateTime.now()});
          break;
          
        case 'NA_FILA':
          await _service.entrarNaFila(viagem.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Status atualizado: Você entrou na fila virtual!'), backgroundColor: Colors.blue),
            );
          }
          break;
        
        case 'EM_DESCARGA':
          await _service.atualizarStatus(viagem.id, StatusOperacional.EM_DESCARGA,
            extras: {'dhChegadaDoca': DateTime.now()});
          break;

        case 'CONCLUIDO':
          setState(() {
            _ultimaViagemConcluida = ViagemModel(
              id: viagem.id,
              motoristaEmail: viagem.motoristaEmail,
              motoristaNome: viagem.motoristaNome,
              placaVeiculo: viagem.placaVeiculo,
              origem: viagem.origem,
              destino: viagem.destino,
              tipoCarga: viagem.tipoCarga,
              statusOperacional: StatusOperacional.CONCLUIDO,
              dhInicio: viagem.dhInicio,
              dhCarregamento: viagem.dhCarregamento,
              dhEntradaFila: viagem.dhEntradaFila,
              dhChamada: viagem.dhChamada,
              dhConclusao: DateTime.now(),
            );
          });
          
          await _service.atualizarStatus(viagem.id, StatusOperacional.CONCLUIDO,
              extras: {'dhConclusao': DateTime.now()});
          break;
          
        case 'QUEBRADO':
          await _service.reportarQuebra(viagem.id);
          break;
          
        case 'CONSERTO':
          await _service.consertarVeiculo(viagem.id);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na operação: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mostrarModalChamado(BuildContext context, ViagemModel viagem) {
    _modalAberto = true; 
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFFE6FCF5), shape: BoxShape.circle),
                  child: const Icon(Icons.phone_in_talk, color: Color(0xFF0CA678), size: 28),
                ),
                const SizedBox(height: 16),
                const Text('É A SUA VEZ!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'O operador está chamando você para a doca de descarga. Dirija-se imediatamente ao local.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: const Color(0xFF495057), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context); 
                    },
                    child: const Text('Entendido, a caminho!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                // NOVO: Botão de emergência direto no Pop-up
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Fecha o pop-up
                    _executarAcao(viagem, 'QUEBRADO'); // Manda para status de Quebrado
                  },
                  child: const Text('Tive um problema / Pular vez', style: TextStyle(color: Color(0xFFFA5252), fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dock Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              Text('Painel do Motorista', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<ViagemModel?>(
        stream: _service.streamViagemAtiva(_user.email!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final viagem = snap.data;

          if (viagem != null && viagem.statusOperacional == StatusOperacional.CHAMADO && !_modalAberto) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mostrarModalChamado(context, viagem);
            });
          }

          // Lógica segura de renderização das telas alternativas
          Widget telaExibida;
          if (_ultimaViagemConcluida != null && !_exibirFormularioNovaViagem) {
            telaExibida = _buildTelaSucessoConcluido(_ultimaViagemConcluida!, cs);
          } else if (viagem == null || _exibirFormularioNovaViagem) {
            telaExibida = _buildNovaViagem(cs);
          } else {
            telaExibida = _buildViagemAtiva(viagem, cs);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                telaExibida,
                const SizedBox(height: 20),
                _buildHistoricoReal(), // Histórico Real e cumulativo do banco de dados
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNovaViagem(ColorScheme cs) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.add, color: Color(0xFF2E7D32), size: 20),
              SizedBox(width: 8),
              Text('Nova Viagem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            ]),
            const SizedBox(height: 20),
            const Text('Placa do Veículo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _placaCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'ABC-1234',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                fillColor: const Color(0xFFF8F9FA),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Origem', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _origemSelecionada,
              hint: const Text('Selecione a origem', style: TextStyle(color: Colors.black38, fontSize: 14)),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                fillColor: const Color(0xFFF8F9FA),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              items: _origens.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _origemSelecionada = v),
            ),
            const SizedBox(height: 16),
            const Text('Tipo de Carga', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _tipoCargaSelecionado,
              hint: const Text('Selecione o tipo', style: TextStyle(color: Colors.black38, fontSize: 14)),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                fillColor: const Color(0xFFF8F9FA),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              items: _tiposCarga.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _tipoCargaSelecionado = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _criarViagem,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF88C4A6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(_loading ? 'Iniciando...' : 'Iniciar Viagem', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViagemAtiva(ViagemModel viagem, ColorScheme cs) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Viagem Ativa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                _buildBadgeStatusVisual(viagem.statusOperacional),
              ],
            ),
            const SizedBox(height: 16),
            _buildCustomStepper(viagem.statusOperacional),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _infoRowClean('Placa', viagem.placaVeiculo),
            _infoRowClean('Rota', '${viagem.origem} → ${viagem.destino}'),
            _infoRowClean('Carga', viagem.tipoCarga),
            _infoRowClean('Início', _formatarData(viagem.dhInicio)),
            if (viagem.dhCarregamento != null) _infoRowClean('Carregado', _formatarData(viagem.dhCarregamento)),
            if (viagem.dhEntradaFila != null) _infoRowClean('Entrada Fila', _formatarData(viagem.dhEntradaFila)),
            if (viagem.dhChamada != null) _infoRowClean('Chamado', _formatarData(viagem.dhChamada)),
            const SizedBox(height: 24),
            _buildBotaoAcaoDinamico(viagem),
          ],
        ),
      ),
    );
  }

  Widget _buildTelaSucessoConcluido(ViagemModel viagem, ColorScheme cs) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFE6FCF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Color(0xFF00875A), size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Viagem Finalizada!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('A descarga na doca foi realizada com sucesso.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _infoRowClean('Placa do Veículo', viagem.placaVeiculo),
            _infoRowClean('Rota Concluída', '${viagem.origem} → ${viagem.destino}'),
            _infoRowClean('Tipo de Carga', alignment: CrossAxisAlignment.end, viagem.tipoCarga),
            _infoRowClean('Horário de Conclusão', _formatarData(viagem.dhConclusao ?? DateTime.now())),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00875A)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() {
                    _ultimaViagemConcluida = null; 
                    _exibirFormularioNovaViagem = true; 
                  });
                },
                icon: const Icon(Icons.add_road, color: Color(0xFF00875A), size: 18),
                label: const Text('Iniciar uma Nova Viagem', style: TextStyle(color: Color(0xFF00875A), fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeStatusVisual(StatusOperacional status) {
    final statusStr = status.toString().split('.').last.toUpperCase();
    
    String label = 'Pendente';
    Color bgColor = const Color(0xFFF1F3F5);
    Color textColor = const Color(0xFF495057);
    IconData icone = Icons.lock_clock;

    if (statusStr == 'CARREGADO') {
      label = 'Carregado'; bgColor = const Color(0xFFE7F5FF); textColor = const Color(0xFF1C7ED6); icone = Icons.inventory_2_outlined;
    } else if (statusStr == 'NA_FILA' || statusStr == 'NAFILA') {
      label = 'Na Fila'; bgColor = const Color(0xFFFFF9DB); textColor = const Color(0xFFF59F00); icone = Icons.people_outline;
    } else if (statusStr == 'QUEBRADO') {
      label = 'Quebrado'; bgColor = const Color(0xFFFFF5F5); textColor = const Color(0xFFFA5252); icone = Icons.warning_amber_rounded;
    } else if (statusStr == 'CHAMADO') {
      label = 'Chamado'; bgColor = const Color(0xFFE6FCF5); textColor = const Color(0xFF00875A); icone = Icons.phone_in_talk;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildCustomStepper(StatusOperacional status) {
    final statusStr = status.toString().split('.').last.toUpperCase();
    
    int etapaAtual = 1;
    if (statusStr == 'CARREGADO') etapaAtual = 2;
    if (statusStr == 'NA_FILA' || statusStr == 'NAFILA' || statusStr == 'QUEBRADO') etapaAtual = 3;
    if (statusStr == 'CHAMADO' || statusStr == 'CONCLUIDO') etapaAtual = 4;

    return Row(
      children: List.generate(7, (index) {
        if (index % 2 == 0) {
          int numeroEtapa = (index ~/ 2) + 1;
          bool concluida = numeroEtapa <= etapaAtual;
          return Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: concluida ? const Color(0xFF00875A) : Colors.grey.shade200,
            ),
          );
        } else {
          int numeroLinha = (index ~/ 2) + 1;
          bool concluida = numeroLinha < etapaAtual;
          return Expanded(
            child: Container(height: 2, color: concluida ? const Color(0xFF00875A) : Colors.grey.shade200),
          );
        }
      }),
    );
  }

  Widget _buildBotaoAcaoDinamico(ViagemModel viagem) {
    final statusStr = viagem.statusOperacional.toString().split('.').last.toUpperCase();

    if (statusStr == 'PENDENTE') {
      return SizedBox(
        width: double.infinity, height: 48,
        child: FilledButton.icon(
          onPressed: _loading ? null : () => _executarAcao(viagem, 'CARREGADO'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00875A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: const Text('Carga Recebida', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }
    
    if (statusStr == 'CARREGADO') {
      return SizedBox(
        width: double.infinity, height: 48,
        child: FilledButton.icon(
          onPressed: _loading ? null : () => _executarAcao(viagem, 'NA_FILA'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00875A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.location_on_outlined, size: 18),
          label: const Text('Passar na PRF', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (statusStr == 'NA_FILA' || statusStr == 'NAFILA') {
      return Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF9DB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFF3BF))),
            child: const Column(
              children: [
                Text('Aguardando chamado do operador...', style: TextStyle(color: Color(0xFFF59F00), fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text('Sua viagem está active na fila virtual', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _executarAcao(viagem, 'QUEBRADO'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDE350B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text('Reportar Quebra', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    if (statusStr == 'QUEBRADO') {
      return Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(12)),
            child: const Column(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFA5252), size: 24),
                SizedBox(height: 6),
                Text('Veículo Impossibilitado', style: TextStyle(color: Color(0xFFFA5252), fontWeight: FontWeight.bold)),
                Text('Sua posição na fila está preservada', style: TextStyle(color: Color(0xFFFA5252), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _executarAcao(viagem, 'CONSERTO'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00875A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.build_outlined, size: 18),
              label: const Text('Conserto Finalizado', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    if (statusStr == 'CHAMADO') {
      return Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FCF5), 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00875A), width: 1.5)
            ),
            child: const Column(
              children: [
                Icon(Icons.phone_in_talk, color: Color(0xFF00875A), size: 24),
                SizedBox(height: 6),
                Text('É A SUA VEZ!', style: TextStyle(color: Color(0xFF00875A), fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Dirija-se à doca imediatamente', style: TextStyle(color: Color(0xFF00875A), fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _executarAcao(viagem, 'EM_DESCARGA'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00875A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Confirmar Chegada na Doca', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          // NOVO: Devolvemos o botão de quebra para o caso de imprevistos a caminho da doca
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : () => _executarAcao(viagem, 'QUEBRADO'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFA5252)), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              icon: const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFFA5252)),
              label: const Text('Tive um problema / Pular vez', style: TextStyle(color: Color(0xFFFA5252), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    if (statusStr == 'EM_DESCARGA') {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFE8F4FD), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD0EBFF))),
        child: const Column(
          children: [
            Icon(Icons.downloading, color: Color(0xFF1C7ED6), size: 28),
            SizedBox(height: 8),
            Text('Veículo na Doca', style: TextStyle(color: Color(0xFF1C7ED6), fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Aguardando o operador confirmar o fim da descarga.', style: TextStyle(color: Colors.black54, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildHistoricoReal() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.history, color: Colors.black54, size: 20),
              SizedBox(width: 8),
              Text('Histórico de Viagens', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            ]),
            const SizedBox(height: 16),
            
            StreamBuilder<List<ViagemModel>>(
              stream: _service.streamHistoricoConcluido(_user.email!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }

                final historico = snapshot.data ?? [];

                if (historico.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nenhuma viagem concluída no histórico.', 
                      textAlign: TextAlign.center, // Corrigido: Agora dentro do widget Text!
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: historico.length,
                  itemBuilder: (context, index) {
                    final item = historico[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.origem} → ${item.destino}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                '${item.placaVeiculo}  •  ${_formatarData(item.dhConclusao).substring(0, 8)}', 
                                style: const TextStyle(color: Colors.black38, fontSize: 12, fontFamily: 'monospace')
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE6FCF5), borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF0CA678), size: 14),
                                SizedBox(width: 4),
                                Text('Concluído', style: TextStyle(color: Color(0xFF0CA678), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRowClean(String label, String value, {CrossAxisAlignment alignment = CrossAxisAlignment.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: alignment,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}