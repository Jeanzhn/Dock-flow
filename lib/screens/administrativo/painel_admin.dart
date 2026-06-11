import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin_service.dart';
import '../../models/veiculo_model.dart';
import '../../models/motorista_model.dart';
import '../auth/login_screen.dart';
import 'mapa_admin_screen.dart';

class PainelAdmin extends StatefulWidget {
  const PainelAdmin({super.key});

  @override
  State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  late TabController _tabController;
  bool _loading = false;
  
  // Variáveis para a Lupa (Filtro de Busca)
  String _pesquisaVeiculo = '';
  String _pesquisaMotorista = '';
  
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ==========================================
  // DIALOGS: VEÍCULOS
  // ==========================================
  void _mostrarDialogNovoVeiculo() {
    final placaCtrl = TextEditingController();
    final placaRegex = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Veículo da Frota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: placaCtrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 7,
          decoration: const InputDecoration(labelText: 'Placa (Ex: ABC1234 ou ABC1A23)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D7D46)),
            onPressed: () async {
              final placaLimpa = placaCtrl.text.trim().toUpperCase();
              if (!placaRegex.hasMatch(placaLimpa)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Placa inválida! Use o formato Padrão ou Mercosul.'), backgroundColor: Colors.orange));
                return;
              }
              Navigator.pop(context);
              setState(() => _loading = true);
              try {
                await _adminService.adicionarVeiculo(placaLimpa);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veículo adicionado!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
              } finally {
                setState(() => _loading = false);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogEditarVeiculo(String placaAntiga) {
    final placaCtrl = TextEditingController(text: placaAntiga);
    final placaRegex = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Placa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: placaCtrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 7,
          decoration: const InputDecoration(labelText: 'Nova Placa', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1C7ED6)),
            onPressed: () async {
              final novaPlaca = placaCtrl.text.trim().toUpperCase();
              if (!placaRegex.hasMatch(novaPlaca)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Placa inválida!'), backgroundColor: Colors.orange));
                return;
              }
              Navigator.pop(context);
              setState(() => _loading = true);
              try {
                await _adminService.editarVeiculo(placaAntiga, novaPlaca);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Placa atualizada com sucesso!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
              } finally {
                setState(() => _loading = false);
              }
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusaoVeiculo(String placa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Veículo?'),
        content: Text('Tem certeza que deseja remover a placa $placa da frota?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              await _adminService.removerVeiculo(placa);
              setState(() => _loading = false);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS: MOTORISTAS
  // ==========================================
  void _mostrarDialogNovoMotorista(List<VeiculoModel> veiculosDisponiveis) {
    final nomeCtrl = TextEditingController();
    final cpfCtrl = TextEditingController();
    List<String> veiculosSelecionados = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Cadastrar Motorista', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nomeCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: cpfCtrl, keyboardType: TextInputType.number, maxLength: 11, decoration: const InputDecoration(labelText: 'CPF (Somente números)', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    const Text('Veículos Permitidos:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    veiculosDisponiveis.isEmpty 
                      ? const Text('Nenhum veículo cadastrado.', style: TextStyle(color: Colors.red, fontSize: 12))
                      : Wrap(
                          spacing: 8,
                          children: veiculosDisponiveis.map((v) {
                            final isSelecionado = veiculosSelecionados.contains(v.placa);
                            return FilterChip(
                              label: Text(v.placa),
                              selected: isSelecionado,
                              selectedColor: const Color(0xFFE6FCF5),
                              checkmarkColor: const Color(0xFF00875A),
                              onSelected: (bool selected) {
                                setStateDialog(() {
                                  if (selected) veiculosSelecionados.add(v.placa);
                                  else veiculosSelecionados.remove(v.placa);
                                });
                              },
                            );
                          }).toList(),
                        ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D7D46)),
                  onPressed: () async {
                    if (nomeCtrl.text.isEmpty || cpfCtrl.text.length < 11) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o nome e CPF válido.'), backgroundColor: Colors.orange));
                      return;
                    }
                    Navigator.pop(context);
                    setState(() => _loading = true);
                    try {
                      await _adminService.criarMotorista(nome: nomeCtrl.text, cpf: cpfCtrl.text, veiculosIniciais: veiculosSelecionados);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Motorista cadastrado!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    } finally {
                      setState(() => _loading = false);
                    }
                  },
                  child: const Text('Cadastrar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _mostrarDialogEditarInfoMotorista(MotoristaModel m) {
    final nomeCtrl = TextEditingController(text: m.nome);
    final cpfCtrl = TextEditingController(text: m.cpf);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Dados Pessoais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: cpfCtrl, keyboardType: TextInputType.number, maxLength: 11, decoration: const InputDecoration(labelText: 'CPF', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1C7ED6)),
            onPressed: () async {
              if (nomeCtrl.text.isEmpty || cpfCtrl.text.length < 11) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados inválidos!'), backgroundColor: Colors.orange));
                return;
              }
              Navigator.pop(context);
              setState(() => _loading = true);
              try {
                await _adminService.editarInfoMotorista(m.id, nomeCtrl.text.trim(), cpfCtrl.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados atualizados!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
              } finally {
                setState(() => _loading = false);
              }
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogEditarVeiculosMotorista(MotoristaModel motorista, List<VeiculoModel> veiculosDisponiveis) {
    List<String> veiculosSelecionados = List.from(motorista.veiculosPermitidos);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Veículos: ${motorista.nome.split(' ')[0]}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selecione os veículos autorizados:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    veiculosDisponiveis.isEmpty 
                      ? const Text('Nenhum veículo cadastrado na frota.', style: TextStyle(color: Colors.red, fontSize: 12))
                      : Wrap(
                          spacing: 8,
                          children: veiculosDisponiveis.map((v) {
                            final isSelecionado = veiculosSelecionados.contains(v.placa);
                            return FilterChip(
                              label: Text(v.placa),
                              selected: isSelecionado,
                              selectedColor: const Color(0xFFE6FCF5),
                              checkmarkColor: const Color(0xFF00875A),
                              onSelected: (bool selected) {
                                setStateDialog(() {
                                  if (selected) veiculosSelecionados.add(v.placa);
                                  else veiculosSelecionados.remove(v.placa);
                                });
                              },
                            );
                          }).toList(),
                        ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D7D46)),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _loading = true);
                    try {
                      await _adminService.atualizarPermissoesVeiculos(motorista.id, veiculosSelecionados);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissões atualizadas!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    } finally {
                      setState(() => _loading = false);
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // AQUI ESTÁ A NOVA FUNÇÃO DE BLOQUEIO / SOFT DELETE
  void _confirmarBloqueioMotorista(MotoristaModel m) {
    final vaiBloquear = m.ativo;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(vaiBloquear ? 'Bloquear Acesso?' : 'Liberar Acesso?'),
        content: Text(vaiBloquear 
          ? 'Tem certeza que deseja bloquear ${m.nome}? Ele não conseguirá mais fazer login no aplicativo.'
          : 'Deseja reativar o acesso de ${m.nome} ao sistema?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: vaiBloquear ? Colors.red : Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              try {
                await _adminService.alternarAcessoMotorista(m.id, m.ativo);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vaiBloquear ? 'Motorista Bloqueado!' : 'Acesso Liberado!'), backgroundColor: vaiBloquear ? Colors.orange : Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
              } finally {
                setState(() => _loading = false);
              }
            },
            child: Text(vaiBloquear ? 'Bloquear' : 'Reativar'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONSTRUÇÃO DAS ABAS
  // ==========================================
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
            decoration: BoxDecoration(color: const Color(0xFF000000), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dock Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              Text('Painel Administrativo', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ]),
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.black54), onPressed: _logout)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2D7D46),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2D7D46),
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping), text: 'Frota'),
            Tab(icon: Icon(Icons.people), text: 'Motoristas'),
            Tab(icon: Icon(Icons.map_outlined), text: 'Geofence')          
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildAbaVeiculos(),
              _buildAbaMotoristas(),
              const MapaAdminScreen(),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildAbaVeiculos() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2D7D46),
        onPressed: _mostrarDialogNovoVeiculo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo Veículo', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // BARRA DE PESQUISA (LUPA)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar placa...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              onChanged: (valor) => setState(() => _pesquisaVeiculo = valor.trim().toUpperCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<VeiculoModel>>(
              stream: _adminService.streamVeiculos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final todosVeiculos = snapshot.data ?? [];
                
                // Aplica o filtro de busca
                final veiculosFiltrados = _pesquisaVeiculo.isEmpty 
                    ? todosVeiculos 
                    : todosVeiculos.where((v) => v.placa.contains(_pesquisaVeiculo)).toList();

                if (veiculosFiltrados.isEmpty) return const Center(child: Text('Nenhum veículo encontrado.'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: veiculosFiltrados.length,
                  itemBuilder: (context, index) {
                    final v = veiculosFiltrados[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFE7F5FF), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.local_shipping, color: Color(0xFF1C7ED6)),
                        ),
                        title: Text('Placa: ${v.placa}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        subtitle: Text(v.ativo ? 'Status: Ativo' : 'Status: Inativo', style: TextStyle(color: v.ativo ? Colors.green : Colors.red)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                              onPressed: () => _mostrarDialogEditarVeiculo(v.placa),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmarExclusaoVeiculo(v.placa),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaMotoristas() {
    return StreamBuilder<List<VeiculoModel>>(
      stream: _adminService.streamVeiculos(),
      builder: (context, veiculoSnap) {
        final veiculosAtuais = veiculoSnap.data ?? [];

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF2D7D46),
            onPressed: () => _mostrarDialogNovoMotorista(veiculosAtuais),
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Novo Motorista', style: TextStyle(color: Colors.white)),
          ),
          body: Column(
            children: [
              // BARRA DE PESQUISA (LUPA)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou CPF...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  onChanged: (valor) => setState(() => _pesquisaMotorista = valor.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<MotoristaModel>>(
                  stream: _adminService.streamMotoristas(),
                  builder: (context, motoristaSnap) {
                    if (motoristaSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    final todosMotoristas = motoristaSnap.data ?? [];
                    
                    // Aplica o filtro de busca
                    final motoristasFiltrados = _pesquisaMotorista.isEmpty 
                        ? todosMotoristas 
                        : todosMotoristas.where((m) => m.nome.toLowerCase().contains(_pesquisaMotorista) || m.cpf.contains(_pesquisaMotorista)).toList();

                    if (motoristasFiltrados.isEmpty) return const Center(child: Text('Nenhum motorista encontrado.'));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: motoristasFiltrados.length,
                      itemBuilder: (context, index) {
                        final m = motoristasFiltrados[index];
                        final bool isAtivo = m.ativo; // Pega o status do bloqueio
                        
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          // Escurece o card se ele estiver bloqueado
                          color: isAtivo ? Colors.white : Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isAtivo ? Colors.grey.shade200 : Colors.red.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(m.nome, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isAtivo ? Colors.black : Colors.grey)),
                                        // Mostra o cadeado vermelho ao lado do nome se estiver bloqueado
                                        if (!isAtivo) const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(Icons.block, color: Colors.red, size: 16),
                                        )
                                      ],
                                    ),
                                    // MENU DE AÇÕES DO MOTORISTA
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          icon: const Icon(Icons.edit_note, color: Colors.orange),
                                          tooltip: 'Editar Dados',
                                          onPressed: () => _mostrarDialogEditarInfoMotorista(m),
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          icon: const Icon(Icons.directions_car, color: Color(0xFF1C7ED6)),
                                          tooltip: 'Editar Veículos',
                                          onPressed: () => _mostrarDialogEditarVeiculosMotorista(m, veiculosAtuais),
                                        ),
                                        // BOTÃO DE BLOQUEIO (Substitui a Lixeira)
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          icon: Icon(isAtivo ? Icons.lock_open : Icons.lock_outline, color: isAtivo ? Colors.red : Colors.green),
                                          tooltip: isAtivo ? 'Bloquear Acesso' : 'Liberar Acesso',
                                          onPressed: () => _confirmarBloqueioMotorista(m),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Login: ${m.emailAcesso}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                Text('CPF: ***.${m.cpf.length > 8 ? m.cpf.substring(3, 6) : '000'}.${m.cpf.length > 8 ? m.cpf.substring(6, 9) : '000'}-**', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                const SizedBox(height: 12),
                                const Text('Veículos Autorizados:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                m.veiculosPermitidos.isEmpty 
                                  ? const Text('Nenhum veículo vinculado', style: TextStyle(color: Colors.orange, fontSize: 12))
                                  : Wrap(
                                      spacing: 6,
                                      children: m.veiculosPermitidos.map((placa) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                                        child: Text(placa, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                      )).toList(),
                                    ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}