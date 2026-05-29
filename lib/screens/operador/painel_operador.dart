import 'package:flutter/material.dart';
import '../../models/viagem_model.dart';
import '../../services/viagem_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class PainelOperador extends StatefulWidget {
  const PainelOperador({super.key});

  @override
  State<PainelOperador> createState() => _PainelOperadorScreenState();
}

class _PainelOperadorScreenState extends State<PainelOperador> with SingleTickerProviderStateMixin {
  final _service = ViagemService();
  final _auth = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF1E4620), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.layers_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
           crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dock Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              Text('Painel do Operador', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ]),
        actions: [
          Row(
            children: [
              Text('Operador', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
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
        ],
      ),
      body: StreamBuilder<List<ViagemModel>>(
        stream: _service.streamTodasAtivas(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final todasViagens = snap.data ?? [];
          
          // SEPARAÇÃO CIRÚRGICA DOS STATUS (Alinhado com as regras do motorista)
          final filaAguardando = todasViagens.where((v) => v.statusOperacional == StatusOperacional.NA_FILA).toList();
          final chamados = todasViagens.where((v) => v.statusOperacional == StatusOperacional.CHAMADO).toList();
          final emTransito = todasViagens.where((v) => v.statusOperacional == StatusOperacional.PENDENTE || v.statusOperacional == StatusOperacional.CARREGADO).toList();
          final quebrados = todasViagens.where((v) => v.statusOperacional == StatusOperacional.QUEBRADO).toList();
          final concluidosFakeCount = 2; 

          // Ordenação FIFO da fila de espera por milissegundos
          filaAguardando.sort((a, b) => (a.posicaoFila ?? 0).compareTo(b.posicaoFila ?? 0));

          // Criamos uma lista unificada para a primeira aba mostrar quem aguarda e quem já foi chamado (separados visualmente)
          final listaAbaFila = [...chamados, ...filaAguardando];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cards Indicadores Superiores
              Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildContadorCard('Na Fila', filaAguardando.length, Icons.people_alt_outlined, const Color(0xFFFFF9DB), const Color(0xFFF59F00)),
                      const SizedBox(width: 16),
                      _buildContadorCard('Chamados', chamados.length, Icons.phone_in_talk_outlined, const Color(0xFFE6FCF5), const Color(0xFF0CA678)),
                      const SizedBox(width: 16),
                      _buildContadorCard('Em Trânsito', emTransito.length, Icons.local_shipping_outlined, const Color(0xFFE7F5FF), const Color(0xFF1C7ED6)),
                      const SizedBox(width: 16),
                      _buildContadorCard('Quebrados', quebrados.length, Icons.warning_amber_rounded, const Color(0xFFFFF5F5), const Color(0xFFFA5252)),
                      const SizedBox(width: 16),
                      _buildContadorCard('Concluídos', concluidosFakeCount, Icons.check_circle_outline, const Color(0xFFF1F3F5), const Color(0xFF495057)),
                    ],
                  ),
                ),
              ),

              // 2. TabBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.black54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: 'Fila (${listaAbaFila.length})'),
                      Tab(text: 'Quebrados (${quebrados.length})'),
                      Tab(text: 'Concluídos ($concluidosFakeCount)'),
                    ],
                  ),
                ),
              ),

              // 3. Conteúdo das Abas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListaMotoristas(listaAbaFila), // Exibe a lista tratada
                    _buildListaMotoristas(quebrados),
                    _buildListaConcluidosFake(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContadorCard(String titulo, int valor, IconData icone, Color bgColor, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icone, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(valor.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildListaMotoristas(List<ViagemModel> viagens) {
    if (viagens.isEmpty) {
      return const Center(child: Text('Nenhum registro encontrado nesta aba.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: viagens.length,
      itemBuilder: (context, index) {
        final viagem = viagens[index];
        final bool isChamado = viagem.statusOperacional == StatusOperacional.CHAMADO;
        
        // Se o cara já foi chamado, não mostra número de posição na fila para fazer sentido operacional
        final String textoPosicao = isChamado ? '--' : '#${index + 1}';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isChamado ? const Color(0xFF00875A) : Colors.grey.shade200, 
              width: isChamado ? 1.5 : 1
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Text(
                            textoPosicao, 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)
                          )
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(viagem.motoristaNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                _buildBadgeStatus(viagem.statusOperacional),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(viagem.placaVeiculo, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                  const SizedBox(width: 12),
                                  Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(viagem.tipoCarga, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(viagem.origem, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Botão de Ação Controlado
                SizedBox(
                  width: 130, height: 36,
                  child: isChamado
                      ? OutlinedButton.icon(
                          onPressed: null, // Desativado estavelmente aguardando o motorista aceitar
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE6FCF5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.phone_in_talk, size: 14, color: Color(0xFF0CA678)),
                          label: const Text('Aguardando', style: TextStyle(color: Color(0xFF0CA678), fontSize: 13, fontWeight: FontWeight.bold)),
                        )
                      : FilledButton.icon(
                          onPressed: () async {
                            // Executa a chamada real no Firebase mudando para CHAMADO
                            await _service.chamarMotorista(viagem.id);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00875A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.phone, size: 14),
                          label: const Text('Chamar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgeStatus(StatusOperacional status) {
    if (status == StatusOperacional.CHAMADO) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFE6FCF5), borderRadius: BorderRadius.circular(6)),
        child: const Text('Chamado', style: TextStyle(color: Color(0xFF0CA678), fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    if (status == StatusOperacional.QUEBRADO) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(6)),
        child: const Text('Quebrado', style: TextStyle(color: const Color(0xFFFA5252), fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFFFF9DB), borderRadius: BorderRadius.circular(6)),
      child: const Text('Na Fila', style: TextStyle(color: Color(0xFFF59F00), fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildListaConcluidosFake() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCardConcluidoFake('João Silva', 'ABC-1234', 'Macapá'),
        _buildCardConcluidoFake('Maria Santos', 'DEF-5678', 'Porto Grande'),
      ],
    );
  }

  Widget _buildCardConcluidoFake(String nome, String placa, String origem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text('$placa  •  $origem → Santana-AP', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE6FCF5), borderRadius: BorderRadius.circular(6)),
              child: const Text('Concluído', style: TextStyle(color: Color(0xFF0CA678), fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }
}