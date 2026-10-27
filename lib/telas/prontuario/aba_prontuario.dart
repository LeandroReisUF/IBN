import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/log_acesso.dart';
import '../../core/paciente.dart';
import '../../core/prontuario.dart';
import '../../core/politica_acesso_service.dart';
import 'aba_anamnese.dart';

/// Aba principal do Prontuário: lista de atendimentos, evoluções, adendos.
class AbaProntuario extends StatefulWidget {
  final Paciente paciente;
  const AbaProntuario({super.key, required this.paciente});

  @override
// Ações
  Future<void> _novoAtendimento() async {
    final agendamentos = agenda.todos
        .where((ag) => ag.pacienteId == _paciente.id && ag.status == StatusAgendamento.emAtendimento)
        .toList();
    
    String? agendamentoId;
    if (agendamentos.isNotEmpty) {
      agendamentoId = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Vincular a agendamento?'),
          children: [
            ...agendamentos.map((ag) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ag.id),
              child: Text('${_formatarDataHora(ag.inicio)} - ${_nomeProfissional(ag.profissionalId)}'),
            )),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Sem agendamento (livre)'),
            ),
          ],
        ),
      );
    }

    if (!mounted) return;
    
    final atendimento = Atendimento(
      id: prontuarioRepository.novoId(),
      pacienteId: _paciente.id,
      profissionalId: _usuario.id,
      agendamentoId: agendamentoId ?? '',
      inicio: DateTime.now(),
      status: StatusAtendimento.emAtendimento,
    );
    
    prontuarioRepository.iniciarAtendimento(atendimento);
    
    if (agendamentoId != null) {
      agenda.mudarStatus(agendamentoId, StatusAgendamento.emAtendimento);
    }
    
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: 'iniciou_atendimento',
      entidade: 'atendimento',
      entidadeId: atendimento.id,
    );
  }
  State<AbaProntuario> createState() => _AbaProntuarioState();
}

// Ações
  Future<void> _acaoAtendimento(String acao, Atendimento a) async {
    switch (acao) {
      case 'encerrar':
        final obs = await _dialogObservacoes('Encerrar atendimento', 'Observações de encerramento (opcional)');
        if (obs != null && mounted) {
          prontuarioRepository.encerrarAtendimento(a.id, observacoes: obs);
          if (a.agendamentoId.isNotEmpty) {
            agenda.mudarStatus(a.agendamentoId, StatusAgendamento.atendido);
          }
        }
        break;
      case 'iniciar':
        final idx = prontuarioRepository._atendimentos.indexWhere((x) => x.id == a.id);
        if (idx >= 0) {
          prontuarioRepository._atendimentos[idx] = a.copiarCom(status: StatusAtendimento.emAtendimento);
          prontuarioRepository.notifyListeners();
          if (a.agendamentoId.isNotEmpty) {
            agenda.mudarStatus(a.agendamentoId, StatusAgendamento.emAtendimento);
          }
        }
        break;
      case 'ver':
        setState(() => _atendimentoAtivo = a);
        _tabController.animateTo(1);
        break;
      case 'anamnese':
        setState(() => _atendimentoAtivo = a);
        break;
    }
  }

  Future<void> _novaEvolucao() async {
    if (_atendimentoAtivo == null) return;
    await showDialog(
      context: context,
      builder: (context) => _DialogEvolucao(
        atendimento: _atendimentoAtivo!,
        onSalvar: (e) {
          prontuarioRepository.adicionarEvolucao(e);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _editarEvolucao(Evolucao e) async {
    await showDialog(
      context: context,
      builder: (context) => _DialogEvolucao(
        atendimento: _atendimentoAtivo!,
        evolucaoExistente: e,
        onSalvar: (nova) {
          final idx = prontuarioRepository._evolucoes.indexWhere((x) => x.id == e.id);
          if (idx >= 0) {
            prontuarioRepository._evolucoes[idx] = nova;
            prontuarioRepository.notifyListeners();
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _assinarEvolucao(Evolucao e) {
    prontuarioRepository.assinarEvolucao(e.id, _usuario.id);
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: 'assinou_evolucao',
      entidade: 'evolucao',
      entidadeId: e.id,
    );
  }

  Future<void> _novoAdendo(Evolucao e) async {
    await showDialog(
      context: context,
      builder: (context) => _DialogAdendo(
        evolucao: e,
        onSalvar: (a) {
          prontuarioRepository.adicionarAdendo(a);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _assinarAdendo(Adendo a) {
    prontuarioRepository.assinarAdendo(a.id, _usuario.id);
  }

  // Helpers
  Color _corStatus(StatusAtendimento s) => switch (s) {
    StatusAtendimento.agendado => Colors.blue,
    StatusAtendimento.emAtendimento => Colors.green,
    StatusAtendimento.atendido => Colors.grey,
    StatusAtendimento.cancelado => Colors.red,
  };
  IconData _iconeStatus(StatusAtendimento s) => switch (s) {
    StatusAtendimento.agendado => Icons.schedule,
    StatusAtendimento.emAtendimento => Icons.medical_services,
    StatusAtendimento.atendido => Icons.check_circle,
    StatusAtendimento.cancelado => Icons.cancel,
  };
  String _formatarDataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';
  String _nomeProfissional(String id) => auth.buscarPorId(id)?.nome ?? '—';

  Future<String?> _dialogObservacoes(String titulo, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: hint), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Confirmar')),
        ],
      ),
    );
  }
}