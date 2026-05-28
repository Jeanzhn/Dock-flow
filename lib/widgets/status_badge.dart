import 'package:flutter/material.dart';
import '../models/viagem_model.dart';

class StatusBadge extends StatelessWidget {
  final StatusOperacional status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _config[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config['color'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'] as IconData, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(config['label'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static final _config = {
    StatusOperacional.PENDENTE:  {'label': 'Pendente',  'icon': Icons.schedule,            'color': Colors.grey},
    StatusOperacional.CARREGADO: {'label': 'Carregado', 'icon': Icons.inventory_2,          'color': Colors.blue},
    StatusOperacional.NA_FILA:   {'label': 'Na Fila',   'icon': Icons.people,               'color': Colors.amber.shade700},
    StatusOperacional.CHAMADO:   {'label': 'Chamado',   'icon': Icons.phone_in_talk,         'color': Colors.green},
    StatusOperacional.CONCLUIDO: {'label': 'Concluído', 'icon': Icons.check_circle,          'color': Colors.teal},
    StatusOperacional.QUEBRADO:  {'label': 'Quebrado',  'icon': Icons.warning_amber_rounded, 'color': Colors.red},
  };
}