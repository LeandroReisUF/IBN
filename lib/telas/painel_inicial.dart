import 'package:flutter/material.dart';
import '../core/agenda_service.dart';
import '../core/agendamento.dart';
import '../core/auth_service.dart';
import '../core/formadores.dart';
import '../core/perfil.dart';
import '../core/politica_acesso_service.dart';
import '../core/sala.dart';

/// Painel inicial, agora alimentado pela agenda real (em memória).
class PainelInicial extends StatelessWidget {
  final Perfil perfil;
  final String nomeUsuario;
  const PainelInicial({
    super.key,
    required this.perfil,
    required this.nomeUsuario,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: agenda,
      builder: (context, _) {
        final usuario = auth.usuarioLogado!;
        final agora = DateTime.now();
        final hoje = soData(agora);
        final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);

        // RN03: profissional só conta os próprios atendimentos.
        final deHoje = politicaAcesso
            .filtrarAgenda(usuario, agenda.todos)
            .where((a) =>
                a.status.ocupaHorario &&
                !a.inicio.isBefore(hoje) &&
                a.inicio.isBefore(amanha))
            .toList();
        final naRecepcao =
            deHoje.where((a) => a.status == StatusAgendamento.naRecepcao).length;
        final emAtendimento =
            deHoje.where((a) => a.status == StatusAgendamento.emAtendimento).length;

        final tituloAgenda =
            perfil.veClinicaInteira ? 'Agendamentos da clínica hoje' : 'Meus atendimentos hoje';

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Olá, $nomeUsuario', style: tema.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Resumo do dia', style: tema.textTheme.bodyMedium),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _CartaoResumo(
                  icone: Icons.event_available_outlined,
                  titulo: tituloAgenda,
                  valor: '${deHoje.length}',
                ),
                _CartaoResumo(
                  icone: Icons.how_to_reg_outlined,
                  titulo: 'Na recepção',
                  valor: '$naRecepcao',
                ),
                _CartaoResumo(
                  icone: Icons.medical_services_outlined,
                  titulo: 'Em atendimento',
                  valor: '$emAtendimento',
                ),
              ],
            ),
            if (perfil.veClinicaInteira) ...[
              const SizedBox(height: 32),
              Text('Salas físicas (agora)', style: tema.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final sala in salas)
                    _CartaoSala(
                      sala: sala,
                      ocupada: agenda.salaOcupadaAgora(sala.numero, agora),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CartaoResumo extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String valor;
  const _CartaoResumo({
    required this.icone,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icone, size: 36, color: tema.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(valor, style: tema.textTheme.headlineMedium),
                    Text(titulo, style: tema.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoSala extends StatelessWidget {
  final Sala sala;
  final bool ocupada;
  const _CartaoSala({required this.sala, required this.ocupada});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cor = ocupada ? tema.colorScheme.error : Colors.green;
    final uso = sala.especialidadesPermitidas.map((e) => e.rotulo).join(', ');
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(sala.nome, style: tema.textTheme.titleMedium),
                  const Spacer(),
                  Icon(Icons.circle, size: 12, color: cor),
                  const SizedBox(width: 6),
                  Text(ocupada ? 'Ocupada' : 'Livre'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                sala.exclusiva ? '$uso (exclusiva)' : '$uso (revezamento)',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}