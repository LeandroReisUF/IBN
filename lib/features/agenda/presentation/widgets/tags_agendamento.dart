import 'package:flutter/material.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';

/// Cor da tag de um tipo de profissional (definida pelo Administrador).
Color corDoTipo(Perfil perfil) => Color(configuracaoClinica.corDoPerfil(perfil));

class _Tag extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color? cor;
  const _Tag(this.icone, this.texto, [this.cor]);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = cor ?? tema.colorScheme.outline;
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      avatar: Icon(icone, size: 14, color: c),
      label: Text(texto, style: tema.textTheme.labelSmall),
      backgroundColor: c.withValues(alpha: 0.14),
      side: BorderSide(color: c),
    );
  }
}

/// Sala, procedimento e profissional como tags, nesta ordem. A tag do
/// profissional leva a cor do tipo dele.
class TagsAgendamento extends StatelessWidget {
  final Agendamento agendamento;
  const TagsAgendamento({super.key, required this.agendamento});

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final sala = buscarSala(a.salaNumero);
    final proc = buscarProcedimento(a.procedimentoId);
    final prof = auth.buscarPorId(a.profissionalId);
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        _Tag(Icons.meeting_room_outlined, sala?.nome ?? 'Sala'),
        _Tag(Icons.medical_services_outlined, proc?.nome ?? 'Procedimento'),
        _Tag(Icons.person_outline, prof?.nome ?? 'Profissional',
            prof == null ? null : corDoTipo(prof.perfil)),
      ],
    );
  }
}

/// Legenda: uma bolinha de cor para cada tipo de profissional.
class LegendaTiposProfissional extends StatelessWidget {
  const LegendaTiposProfissional({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListenableBuilder(
      listenable: configuracaoClinica,
      builder: (context, _) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final e in configuracaoClinica.coresPerfil.entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: Color(e.value), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(e.key.rotulo, style: tema.textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}