import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Importa o seu arquivo main.dart
import 'package:dock_flow/main.dart';

void main() {
  testWidgets('Teste de inicialização da Tela de Perfil', (WidgetTester tester) async {
    // 1. Constrói o seu app logístico
    await tester.pumpWidget(const MeuAppLogistico());

    // 2. Verifica se a barra superior "Selecione seu Perfil" apareceu
    expect(find.text('Selecione seu Perfil'), findsOneWidget);

    // 3. Verifica se os botões estão na tela
    expect(find.text('Entrar como OPERADOR / CHEFE'), findsOneWidget);
    expect(find.text('Entrar como MOTORISTA'), findsOneWidget);
    
    // 4. Verifica que não tem nenhum contador antigo perdido na tela
    expect(find.text('0'), findsNothing);
  });
}