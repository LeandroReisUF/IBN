import 'package:flutter/material.dart';
import '../core/modulos.dart';

/// Tela provisória: cada módulo ganhará sua tela real nas próximas etapas.
class TelaModuloEmConstrucao extends StatelessWidget {
  final Modulo modulo;
  const TelaModuloEmConstrucao({super.key, required this.modulo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(modulo.icone, size: 64, color: tema.colorScheme.outline),
          const SizedBox(height: 16),
          Text('${modulo.titulo} — em construção',
              style: tema.textTheme.titleLarge),
        ],
      ),
    );
  }
}