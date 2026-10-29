import 'package:flutter/foundation.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/auth/data/auth_service.dart';

/// Regras da agenda (RF02, RN01, RN02). Dados em memória (PROVISÓRIO).
class AgendaService extends ChangeNotifier {
  final List<Agendamento> _lista = [];
  int _contador = 0;

  AgendaService({bool comExemplos = true}) {
    if (comExemplos) _lista.addAll(_exemplos());
  }

  List<Agendamento> get todos => List.unmodifiable(_lista);

  String novoId() {
    _contador++;
    return 'a${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  /// Dois intervalos se sobrepõem? Horários que apenas "encostam" não contam
  /// (09:00–09:30 e 09:30–10:00 não conflitam).
  static bool sobrepoe(DateTime aIni, DateTime aFim, DateTime bIni, DateTime bFim) =>
      aIni.isBefore(bFim) && bIni.isBefore(aFim);

  Agendamento? _primeiroConflito(
    bool Function(Agendamento) mesmoRecurso,
    DateTime ini,
    DateTime fim,
    String? ignorarId,
  ) {
    for (final a in _lista) {
      if (a.id == ignorarId || !a.status.ocupaHorario) continue;
      if (mesmoRecurso(a) && sobrepoe(ini, fim, a.inicio, a.fim)) return a;
    }
    return null;
  }

  bool salaDisponivel(int sala, DateTime ini, DateTime fim, {String? ignorarId}) =>
      _primeiroConflito((a) => a.salaNumero == sala, ini, fim, ignorarId) == null;

  bool profissionalDisponivel(String profissionalId, DateTime ini, DateTime fim,
          {String? ignorarId}) =>
      _primeiroConflito((a) => a.profissionalId == profissionalId, ini, fim, ignorarId) ==
      null;

  bool salaOcupadaAgora(int sala, DateTime agora) => !salaDisponivel(
        sala,
        agora,
        agora.add(const Duration(minutes: 1)),
      );

  /// Devolve a mensagem de erro, ou null se o agendamento é válido.
  String? validarConflitos(Agendamento ag) {
    if (!ag.fim.isAfter(ag.inicio)) {
      return 'O horário final deve ser depois do inicial.';
    }
    final proc = buscarProcedimento(ag.procedimentoId);
    if (proc == null) return 'Procedimento não encontrado.';

    final prof = auth.buscarPorId(ag.profissionalId);
    if (prof == null || !prof.perfil.especialidades.contains(proc.especialidade)) {
      final nome = prof == null ? 'O profissional' : prof.nome;
      return '$nome não realiza ${proc.especialidade.rotulo}.';
    }

    final sala = buscarSala(ag.salaNumero);
    if (sala == null) return 'Sala não encontrada.';
    if (!sala.permiteEspecialidade(proc.especialidade)) {
      return 'A ${sala.nome} não pode ser usada para ${proc.especialidade.rotulo} (RN01).';
    }

    final cSala = _primeiroConflito((a) => a.salaNumero == ag.salaNumero, ag.inicio, ag.fim, ag.id);
    if (cSala != null) {
      return 'A ${sala.nome} já está ocupada das ${formatarHora(cSala.inicio)} às ${formatarHora(cSala.fim)} (RN02).';
    }

    final cProf = _primeiroConflito(
        (a) => a.profissionalId == ag.profissionalId, ag.inicio, ag.fim, ag.id);
    if (cProf != null) {
      final outraSala = buscarSala(cProf.salaNumero);
      final nomeSala = outraSala == null ? 'outra sala' : outraSala.nome;
      return '${prof.nome} já tem atendimento das ${formatarHora(cProf.inicio)} às ${formatarHora(cProf.fim)} na $nomeSala (RN02).';
    }
    return null;
  }

  /// Cria o agendamento. Retorna a mensagem de erro, ou null se deu certo.
  String? criar(Agendamento ag) {
    final erro = validarConflitos(ag);
    if (erro != null) return erro;
    _lista.add(ag);
    _vincularPaciente(ag);
    notifyListeners();
    return null;
  }

  String? atualizar(Agendamento ag) {
    final i = _lista.indexWhere((a) => a.id == ag.id);
    if (i < 0) return 'Agendamento não encontrado.';
    final erro = validarConflitos(ag);
    if (erro != null) return erro;
    _lista[i] = ag;
    _vincularPaciente(ag);
    notifyListeners();
    return null;
  }

  /// Muda o status. Reativar um agendamento desmarcado revalida os conflitos.
  String? mudarStatus(String id, StatusAgendamento novo) {
    final i = _lista.indexWhere((a) => a.id == id);
    if (i < 0) return 'Agendamento não encontrado.';
    final atualizado = _lista[i].copiarCom(status: novo);
    if (novo.ocupaHorario && !_lista[i].status.ocupaHorario) {
      final erro = validarConflitos(atualizado);
      if (erro != null) return erro;
    }
    _lista[i] = atualizado;
    notifyListeners();
    return null;
  }

  /// RN03: ao agendar, o paciente é vinculado automaticamente ao
  /// profissional (a PESSOA escolhida, não a especialidade).
  void _vincularPaciente(Agendamento ag) {
    final p = pacientes.buscarPorId(ag.pacienteId);
    if (p == null || p.profissionaisVinculados.contains(ag.profissionalId)) return;
    pacientes.salvar(p.copiarCom(
      profissionaisVinculados: {...p.profissionaisVinculados, ag.profissionalId},
    ));
  }

  List<Agendamento> _exemplos() {
    final hoje = soData(DateTime.now());
    DateTime h(int hora, int min, {int dias = 0}) =>
        DateTime(hoje.year, hoje.month, hoje.day + dias, hora, min);

    Agendamento ex(String id, String paciente, String prof, int sala,
        String procId, DateTime ini, StatusAgendamento st) {
      final proc = buscarProcedimento(procId)!;
      return Agendamento(
        id: id,
        pacienteId: paciente,
        profissionalId: prof,
        salaNumero: sala,
        procedimentoId: procId,
        inicio: ini,
        fim: ini.add(Duration(minutes: proc.duracaoMinutos)),
        status: st,
      );
    }

    return [
      ex('a1', 'p1', '3', 3, 'consulta-odontologica', h(8, 0), StatusAgendamento.confirmadoWhatsapp),
      ex('a2', 'p2', '5', 1, 'consulta-medica', h(9, 0), StatusAgendamento.naRecepcao),
      ex('a3', 'p3', '9', 2, 'sessao-psicologia', h(9, 0), StatusAgendamento.agendado),
      ex('a4', 'p3', '4', 4, 'peeling', h(10, 30), StatusAgendamento.agendado),
      ex('a5', 'p4', '7', 1, 'sessao-fisioterapia', h(14, 0), StatusAgendamento.agendado),
      ex('a6', 'p4', '3', 3, 'consulta-odontologica', h(8, 30, dias: 1), StatusAgendamento.agendado),
      ex('a7', 'p1', '8', 2, 'consulta-nutricional', h(10, 0, dias: 1), StatusAgendamento.agendado),
    ];
  }
}

final agenda = AgendaService();