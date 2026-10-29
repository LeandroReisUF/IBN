/// Prontuário base (RF03, RN05): Atendimento, Evolução e Adendo.
/// Todas as classes são imutáveis; mudanças criam cópias (`copiarCom`).
/// A Anamnese entra no Passo 6, em arquivo próprio.

/// Situação de um atendimento.
enum StatusAtendimento {
  emAtendimento('Em atendimento'),
  encerrado('Encerrado');

  final String rotulo;
  const StatusAtendimento(this.rotulo);
}

/// Tipo de evolução. (SOAP entra na Sprint 2, com Medicina/Enfermagem.)
enum TipoEvolucao {
  livre('Evolução livre'),
  procedimento('Procedimento realizado'),
  retorno('Retorno');

  final String rotulo;
  const TipoEvolucao(this.rotulo);
}

/// Uma sessão clínica de um profissional com um paciente.
/// Depois de encerrado, nada nele muda (RN05).
class Atendimento {
  final String id;
  final String pacienteId;
  final String profissionalId;
  final String? agendamentoId;
  final DateTime inicio;
  final DateTime? fim;
  final StatusAtendimento status;
  final String? observacoesEncerramento;

  const Atendimento({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    this.agendamentoId,
    required this.inicio,
    this.fim,
    this.status = StatusAtendimento.emAtendimento,
    this.observacoesEncerramento,
  });

  bool get encerrado => status == StatusAtendimento.encerrado;

  Atendimento copiarCom({
    DateTime? fim,
    StatusAtendimento? status,
    String? observacoesEncerramento,
  }) =>
      Atendimento(
        id: id,
        pacienteId: pacienteId,
        profissionalId: profissionalId,
        agendamentoId: agendamentoId,
        inicio: inicio,
        fim: fim ?? this.fim,
        status: status ?? this.status,
        observacoesEncerramento: observacoesEncerramento ?? this.observacoesEncerramento,
      );
}

/// Registro clínico escrito durante um atendimento.
/// Enquanto não assinada é um rascunho (pode editar ou descartar).
/// Assinada, fica imutável: correção só por [Adendo] (RN05).
class Evolucao {
  final String id;
  final String atendimentoId;
  final String pacienteId;
  final String profissionalId;
  final TipoEvolucao tipo;
  final String texto;
  final DateTime dataHora;
  final bool assinada;
  final DateTime? assinadaEm;

  /// PROVISÓRIO: selo de integridade simples. Não é assinatura digital;
  /// o servidor passará a gerar um hash/assinatura real.
  final String? selo;

  const Evolucao({
    required this.id,
    required this.atendimentoId,
    required this.pacienteId,
    required this.profissionalId,
    required this.tipo,
    required this.texto,
    required this.dataHora,
    this.assinada = false,
    this.assinadaEm,
    this.selo,
  });

  Evolucao copiarCom({
    String? texto,
    bool? assinada,
    DateTime? assinadaEm,
    String? selo,
  }) =>
      Evolucao(
        id: id,
        atendimentoId: atendimentoId,
        pacienteId: pacienteId,
        profissionalId: profissionalId,
        tipo: tipo,
        texto: texto ?? this.texto,
        dataHora: dataHora,
        assinada: assinada ?? this.assinada,
        assinadaEm: assinadaEm ?? this.assinadaEm,
        selo: selo ?? this.selo,
      );
}

/// Correção ou acréscimo a uma evolução já assinada (RN05).
/// É assinado no momento em que é criado (o repositório preenche a assinatura).
class Adendo {
  final String id;
  final String evolucaoId;
  final String pacienteId;
  final String profissionalId;
  final String justificativa;
  final String texto;
  final DateTime dataHora;
  final bool assinado;
  final String? selo;

  const Adendo({
    required this.id,
    required this.evolucaoId,
    required this.pacienteId,
    required this.profissionalId,
    required this.justificativa,
    required this.texto,
    required this.dataHora,
    this.assinado = false,
    this.selo,
  });

  Adendo copiarCom({bool? assinado, String? selo}) => Adendo(
        id: id,
        evolucaoId: evolucaoId,
        pacienteId: pacienteId,
        profissionalId: profissionalId,
        justificativa: justificativa,
        texto: texto,
        dataHora: dataHora,
        assinado: assinado ?? this.assinado,
        selo: selo ?? this.selo,
      );
}