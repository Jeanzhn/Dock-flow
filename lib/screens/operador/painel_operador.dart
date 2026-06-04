import 'package:flutter/material.dart';
import '../../models/viagem_model.dart';
import '../../services/viagem_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'package:intl/intl.dart';
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
      // Mude o stream principal [cite: 202]
      body: StreamBuilder<List<ViagemModel>>(
        stream: _service.streamTodasViagensOperador(), // <-- 1. ATUALIZE AQUI
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // [cite: 203]
          }

          final todasViagens = snap.data ?? [];
          final filaAguardando = todasViagens.where((v) => v.statusOperacional == StatusOperacional.NA_FILA).toList();
          final chamados = todasViagens.where((v) => v.statusOperacional == StatusOperacional.CHAMADO).toList();
          final emDescarga = todasViagens.where((v) => v.statusOperacional == StatusOperacional.EM_DESCARGA).toList();
          final emTransito = todasViagens.where((v) => v.statusOperacional == StatusOperacional.PENDENTE || v.statusOperacional == StatusOperacional.CARREGADO).toList();
          final quebrados = todasViagens.where((v) => v.statusOperacional == StatusOperacional.QUEBRADO).toList();
          final concluidos = todasViagens.where((v) => v.statusOperacional == StatusOperacional.CONCLUIDO).toList();

          // Ordenação FIFO da fila de espera por milissegundos
          filaAguardando.sort((a, b) => (a.posicaoFila ?? 0).compareTo(b.posicaoFila ?? 0));

          // Criamos uma lista unificada para a primeira aba mostrar quem aguarda e quem já foi chamado (separados visualmente)
          final listaAbaFila = [...emDescarga, ...chamados, ...filaAguardando];

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
                      _buildContadorCard('Concluídos', concluidos.length, Icons.check_circle_outline, const Color(0xFFF1F3F5), const Color(0xFF495057)),
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
                      Tab(text: 'Concluídos (${concluidos.length})'),
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
                    _buildListaConcluidosReal(concluidos),
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
                // ==========================================
                // BOTÃO DE AÇÃO CONTROLADO E DINÂMICO
                // ==========================================
                SizedBox(
                  width: 140, height: 36,
                  child: () {
                    if (viagem.statusOperacional == StatusOperacional.EM_DESCARGA) {
                      return FilledButton.icon(
                        onPressed: () async => await _service.atualizarStatus(viagem.id, StatusOperacional.CONCLUIDO, extras: {'dhConclusao': DateTime.now()}),
                        style: FilledButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        icon: const Icon(Icons.check_box, size: 14),
                        label: const Text('Descarregou', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    } else if (isChamado) {
                      return OutlinedButton.icon(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE6FCF5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        icon: const Icon(Icons.phone_in_talk, size: 14, color: Color(0xFF0CA678)),
                        label: const Text('Aguardando', style: TextStyle(color: Color(0xFF0CA678), fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    } else if (viagem.statusOperacional == StatusOperacional.QUEBRADO) {
                      // NOVO: Trava de segurança para não chamar caminhão quebrado
                      return OutlinedButton.icon(
                        onPressed: null, // Totalmente desativado para o operador
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFFF5F5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        icon: const Icon(Icons.build, size: 14, color: Color(0xFFFA5252)),
                        label: const Text('Manutenção', style: TextStyle(color: Color(0xFFFA5252), fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    } else {
                      return FilledButton.icon(
                        onPressed: () async => await _service.chamarMotorista(viagem.id),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00875A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        icon: const Icon(Icons.phone, size: 14),
                        label: const Text('Chamar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      );
                    }
                  }(),
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

  Widget _buildListaConcluidosReal(List<ViagemModel> concluidos) {
    if (concluidos.isEmpty) {
      return const Center(child: Text('Nenhuma viagem concluída.', style: TextStyle(color: Colors.grey)));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: concluidos.length,
      itemBuilder: (context, index) {
        final v = concluidos[index];
        // Passa os dados reais para o seu Card já existente [cite: 253, 254]
        return _buildCardConcluidoReal(v);
      },
    );
  }

  Widget _buildCardConcluidoReal(ViagemModel viagem) {
    // Formata os horários. Se por acaso estiver vazio (viagens antigas de teste), mostra --:--
    String hrChegada = viagem.dhChegadaDoca != null ? DateFormat('dd/MM/yy HH:mm').format(viagem.dhChegadaDoca!) : '--:--';
    String hrSaida = viagem.dhConclusao != null ? DateFormat('dd/MM/yy HH:mm').format(viagem.dhConclusao!) : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(viagem.motoristaNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE6FCF5), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Concluído', style: TextStyle(color: Color(0xFF0CA678), fontWeight: FontWeight.bold, fontSize: 11)),
                )
              ],
            ),
            const SizedBox(height: 6),
            Text('${viagem.placaVeiculo}  •  ${viagem.origem} → Santana-AP', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chegou na Doca:\n$hrChegada', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  Text('Fim da Descarga:\n$hrSaida', style: const TextStyle(fontSize: 12, color: Colors.black87), textAlign: TextAlign.right),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}