import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/ponto_controle_model.dart';
import '../../services/admin_service.dart';

class MapaAdminScreen extends StatefulWidget {
  const MapaAdminScreen({super.key});

  @override
  State<MapaAdminScreen> createState() => _MapaAdminScreenState();
}

class _MapaAdminScreenState extends State<MapaAdminScreen> {
  final _adminService = AdminService();
  final MapController _mapController = MapController();
  PontoControleModel? _pontoSendoMovido;
  // Foco inicial do mapa (Santana-AP)
  final LatLng _posicaoInicial = const LatLng(-0.0401, -51.1738);

  // ==========================================
  // DIALOG PARA CRIAR NOVO PONTO
  // ==========================================
  void _mostrarDialogNovoPonto(LatLng coordenadas) {
    final nomeCtrl = TextEditingController();
    double raioAtual = 50.0;
    String acaoSelecionada = 'CARREGAMENTO';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Novo Ponto de Triagem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nome do Ponto (Ex: Pátio B)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo de Ação Obrigatória:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: acaoSelecionada,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'CARREGAMENTO', child: Text('Área de Carregamento')),
                        DropdownMenuItem(value: 'FILA', child: Text('Posto de Entrada na Fila')),
                        DropdownMenuItem(value: 'DOCA', child: Text('Área da Doca (Descarga)')),
                      ],
                      onChanged: (v) => setStateDialog(() => acaoSelecionada = v!),
                    ),
                    const SizedBox(height: 16),
                    Text('Raio de Permissão: ${raioAtual.toInt()} metros', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: raioAtual,
                      min: 10,
                      max: 500,
                      divisions: 49,
                      activeColor: const Color(0xFF00875A),
                      onChanged: (v) => setStateDialog(() => raioAtual = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
                  onPressed: () async {
                    if (nomeCtrl.text.isEmpty) return;
                    Navigator.pop(context);
                    
                    final novoPonto = PontoControleModel(
                      id: '',
                      nome: nomeCtrl.text,
                      lat: coordenadas.latitude,
                      lng: coordenadas.longitude,
                      raioMetros: raioAtual,
                      tipoAcao: acaoSelecionada,
                    );
                    
                    await _adminService.adicionarPontoControle(novoPonto);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto salvo no mapa!'), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('Salvar Ponto'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // ==========================================
  // DIALOG PARA EDITAR OU EXCLUIR PONTO
  // ==========================================
  void _mostrarDialogEditarPonto(PontoControleModel ponto) {
    double raioAtual = ponto.raioMetros;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(ponto.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _getCorPorTipo(ponto.tipoAcao).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text('Ação: ${ponto.tipoAcao}', style: TextStyle(color: _getCorPorTipo(ponto.tipoAcao), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 24),
                  Text('Raio de Permissão: ${raioAtual.toInt()} metros', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: raioAtual,
                    min: 10,
                    max: 500,
                    divisions: 49,
                    activeColor: const Color(0xFF00875A),
                    onChanged: (v) => setStateDialog(() => raioAtual = v),
                  ),
                ],
              ),
              actions: [
                // Botão de Excluir foi movido para cá
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmarExclusao(ponto);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('Excluir', style: TextStyle(color: Colors.red)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _pontoSendoMovido = ponto);
                  },
                  icon: const Icon(Icons.pin_drop_outlined, color: Colors.blue, size: 18),
                  label: const Text('Mover', style: TextStyle(color: Colors.blue)),
                ),
                
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),

                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _adminService.atualizarRaioPontoControle(ponto.id, raioAtual);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raio atualizado com sucesso!'), backgroundColor: Colors.green));
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

  // ==========================================
  // DIALOG PARA CONFIRMAR EXCLUSÃO
  // ==========================================
  void _confirmarExclusao(PontoControleModel ponto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Ponto?'),
        content: Text('Deseja excluir o ponto de triagem "${ponto.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _adminService.removerPontoControle(ponto.id);
              Navigator.pop(context);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  // Define a cor visual de acordo com o tipo
  Color _getCorPorTipo(String tipo) {
    if (tipo == 'CARREGAMENTO') return const Color(0xFF1C7ED6); // Azul
    if (tipo == 'FILA') return const Color(0xFFF59F00); // Laranja
    return const Color(0xFF00875A); // Verde
  }

  IconData _getIconePorTipo(String tipo) {
    if (tipo == 'CARREGAMENTO') return Icons.inventory_2;
    if (tipo == 'FILA') return Icons.signpost;
    return Icons.warehouse;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Triagem', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<List<PontoControleModel>>(
        stream: _adminService.streamPontosControle(),
        builder: (context, snapshot) {
          final pontos = snapshot.data ?? [];

          // Listas que o flutter_map entende
          List<CircleMarker> circulos = [];
          List<Marker> marcadores = [];

          for (var p in pontos) {
            final cor = _getCorPorTipo(p.tipoAcao);
            final icone = _getIconePorTipo(p.tipoAcao);
            
            // 1. A área invisível / bolha de restrição
            circulos.add(
              CircleMarker(
                point: LatLng(p.lat, p.lng),
                color: cor.withOpacity(0.25),
                borderColor: cor,
                borderStrokeWidth: 2,
                radius: p.raioMetros, // O raio que você definiu no Slider
                useRadiusInMeter: true, // ESSENCIAL: Garante que 50 = 50 metros na vida real
              ),
            );

            // 2. O pino visual
            marcadores.add(
              Marker(
                point: LatLng(p.lat, p.lng),
                width: 60,
                height: 60,
                child: GestureDetector(
                  onTap: () => _mostrarDialogEditarPonto(p), // Clicou no pino, pergunta se quer apagar
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: cor, width: 2)),
                        child: Icon(icone, color: cor, size: 20),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                        child: Text(p.nome, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      )
                    ],
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _posicaoInicial,
                  initialZoom: 14.0,
                  // Quando o Admin segura o clique na rua, chama a função de criar
                  onLongPress: (tapPosition, point) => _mostrarDialogNovoPonto(point),
                  onTap: (tapPosition, point) async {
                    if (_pontoSendoMovido != null) {
                      await _adminService.atualizarPosicaoPonto(_pontoSendoMovido!.id, point.latitude, point.longitude);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto reposicionado!'), backgroundColor: Colors.green));
                      }
                      setState(() => _pontoSendoMovido = null);
                    }
                  },
                ),
                children: [
                  // Camada de imagens de rua do OpenStreetMap (Gratuita)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.dockflow.app',
                  ),
                  CircleLayer(circles: circulos),
                  MarkerLayer(markers: marcadores),
                ],
                
              ),
              
              // Banner de instrução no topo
              Positioned(
                top: 16, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _pontoSendoMovido != null ? Colors.blue.shade900 : Colors.white, 
                    borderRadius: BorderRadius.circular(8), 
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pontoSendoMovido != null ? Icons.touch_app : Icons.touch_app_outlined, 
                        color: _pontoSendoMovido != null ? Colors.white : const Color(0xFF00875A)
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pontoSendoMovido != null 
                            ? 'Clique no mapa para reposicionar o ponto "${_pontoSendoMovido!.nome}".'
                            : 'Segure o clique na rua para criar um Ponto de Triagem.', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                            color: _pontoSendoMovido != null ? Colors.white : Colors.black87
                          )
                        )
                      ),
                      if (_pontoSendoMovido != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => _pontoSendoMovido = null),
                        )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}