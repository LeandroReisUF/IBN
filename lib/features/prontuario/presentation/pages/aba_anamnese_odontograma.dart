import 'package:flutter/material.dart';
import 'package:ibn/features/anamnese/presentation/pages/aba_anamnese.dart';
import 'package:ibn/features/odontograma/presentation/pages/aba_odontograma.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';

/// Primeira aba do dentista: uma janela só, na ordem do atendimento.
/// Anamnese (com o Exame físico) e, logo abaixo, o Odontograma. Cada bloco abre
/// e fecha ao tocar no título, para dar espaço ao seguinte.
class AbaAnamneseOdontograma extends StatelessWidget {
  final Paciente paciente;
  const AbaAnamneseOdontograma({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnamneseInline(paciente: paciente),
            const SizedBox(height: 8),
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                key: const ValueKey('bloco-odontograma'),
                maintainState: true,
                title: Text('Odontograma', style: tema.textTheme.titleMedium),
                children: [AbaOdontograma(paciente: paciente, embutido: true)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}