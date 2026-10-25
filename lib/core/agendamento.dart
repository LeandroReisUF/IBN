/// Status do agendamento (RF02.3).
enum StatusAgendamento {
  agendado('Agendado'),
  confirmadoWhatsapp('Confirmado via WhatsApp'),
  naRecepcao('Na recepção'),
  emAtendimento('Em atendimento'),
  atendido('Atendido'),
  faltouDesmarcou('Faltou/Desmarcou');

  final String rotulo;
  const StatusAgendamento(this.rotulo);

  /// Faltou/Desmarcou libera a sala e o profissional naquele horário.
  bool get ocupaHorario => this != StatusAgendamento.faltouDesmarcou;
}

class Agendamento {
  final String id;
  final String pacienteId;
  final String profissionalId; // ID do Usuario (pessoa, não cargo)
  final int salaNumero;
  final String procedimentoId;
  final DateTime inicio;
  final DateTime fim;
  final StatusAgendamento status;
  final String observacoes;

  const Agendamento({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    required this.salaNumero,
    required this.procedimentoId,
    required this.inicio,
    required this.fim,
    this.status = StatusAgendamento.agendado,
    this.observacoes = '',
  });

  Agendamento copiarCom({StatusAgendamento? status}) {
    return Agendamento(
      id: id,
      pacienteId: pacienteId,
      profissionalId: profissionalId,
      salaNumero: salaNumero,
      procedimentoId: procedimentoId,
      inicio: inicio,
      fim: fim,
      status: status ?? this.status,
      observacoes: observacoes,
    );
  }
}