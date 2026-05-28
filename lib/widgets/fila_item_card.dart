import 'package:flutter/material.dart';
import '../models/viagem_model.dart';
import 'status_badge.dart';

class FilaItemCard extends StatelessWidget {
  final ViagemModel viagem;
  final int posicao;
  final VoidCallback? onChamar;
  final bool isChamando;

  const FilaItemCard({
    super.key,
    required this.viagem,
    required this.posicao,
    required this.onChamar,
    required this.isChamando,
  });

  @override
  Widget build(BuildContext context) {
    final isChamado = viagem.statusOperacional == StatusOperacional.CHAMADO;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isChamado ? BorderSide(color: cs.primary, width: 2) : BorderSide.none,
      ),
      color: isChamado ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Position number
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  isChamado ? '📞' : '#$posicao',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isChamado ? 18 : 14,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(viagem.motoristaNome,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  StatusBadge(status: viagem.statusOperacional),
                  const SizedBox(height: 4),
                  Text('${viagem.placaVeiculo} · ${viagem.tipoCarga} · ${viagem.origem}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            // Action button
            if (viagem.statusOperacional == StatusOperacional.NA_FILA && onChamar != null)
              FilledButton.icon(
                onPressed: isChamando ? null : onChamar,
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Chamar'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }
}