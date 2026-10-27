import 'package:flutter/foundation.dart';
import 'condicao_odonto.dart';

/// Status de um atendimento.
enum StatusAtendimento {
  agendado('Agendado'),
  emAtendimento('Em atendimento'),
  atendido('Atendido'),
  cancelado('Cancelado');

  final String rotulo;
  const StatusAtendimento(this.rotulo);
}

/// Tipo de evolução (SOAP, livre, etc.).
enum TipoEvolucao {
  soap('SOAP'),
  livre('Livre'),
  procedimento('Procedimento'),
  retorno('Retorno');

  final String rotulo;
  const TipoEvolucao(this.rotulo);
}

/// Prontuário do paciente (agregador).
class Prontuario {
  final String id;
  final String pacienteId;
  final DateTime criadoEm;

  const Prontuario({
    required this.id,
    required this.pacienteId,
    required this.criadoEm,
  });
}

/// Um atendimento clínico (gera evoluções, documentos, exames, etc.).
class Atendimento {
  final String id;
  final String pacienteId;
  final String profissionalId;
  final String agendamentoId;
  final DateTime inicio;
  DateTime? fim;
  StatusAtendimento status;
  final String? observacoesGerais;

  const Atendimento({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    required this.agendamentoId,
    required this.inicio,
    this.fim,
    this.status = StatusAtendimento.emAtendimento,
    this.observacoesGerais,
  });

  Atendimento copiarCom({
    DateTime? fim,
    StatusAtendimento? status,
    String? observacoesGerais,
  }) =>
      Atendimento(
        id: id,
        pacienteId: pacienteId,
/// Uma evolução (registro clínico) dentro de um atendimento.
/// Imutável após assinada (RN05) — correção só via Adendo.
class Evolucao {
  final String id;
  final String atendimentoId;
  final String profissionalId;
  final TipoEvolucao tipo;
  final String texto; // JSON para SOAP, texto livre para outros
  final DateTime dataHora;
  bool assinada;
  final String? assinaturaHash; // hash da assinatura digital

  const Evolucao({
    required this.id,
    required this.atendimentoId,
    required this.profissionalId,
    required this.tipo,
    required this.texto,
    required this.dataHora,
    this.assinada = false,
    this.assinaturaHash,
  });

  Evolucao copiarCom({
    bool? assinada,
    String? assinaturaHash,
  }) =>
      Evolucao(
        id: id,
        atendimentoId: atendimentoId,
        profissionalId: profissionalId,
        tipo: tipo,
        texto: texto,
        dataHora: dataHora,
        assinada: assinada ?? this.assinada,
        assinaturaHash: assinaturaHash ?? this.assinaturaHash,
      );

  /// RN05: evolução assinada não pode ser alterada.
  bool get podeEditar => !assinada;
}

/// Adendo (correção/acréscimo) a uma evolução já assinada (RN05).
class Adendo {
  final String id;
  final String evolucaoId; // evolução original
  final String profissionalId;
  final String justificativa;
  final String texto; // conteúdo do adendo
  final DateTime dataHora;
  bool assinado;
  final String? assinaturaHash;

  const Adendo({
    required this.id,
    required this.evolucaoId,
    required this.profissionalId,
    required this.justificativa,
    required this.texto,
    required this.dataHora,
    this.assinado = false,
    this.assinaturaHash,
  });

  Adendo copiarCom({
    bool? assinado,
    String? assinaturaHash,
  }) =>
      Adendo(
        id: id,
        evolucaoId: evolucaoId,
        profissionalId: profissionalId,
        justificativa: justificativa,
/// Modelo de pergunta de anamnese.
enum TipoRespostaAnamnese {
  texto('Texto livre'),
  textoLongo('Texto longo'),
  booleano('Sim/Não'),
  multiplaEscolha('Múltipla escolha'),
  unicaEscolha('Única escolha'),
  escala('Escala 1-10'),
  data('Data');

  final String rotulo;
  const TipoRespostaAnamnese(this.rotulo);
}

/// Pergunta de um modelo de anamnese.
class PerguntaAnamnese {
  final String id;
  final String enunciado;
  final TipoRespostaAnamnese tipo;
  final bool obrigatoria;
  final List<String> opcoes; // para multipla/unica escolha
  final String? ajuda; // texto de ajuda

  const PerguntaAnamnese({
    required this.id,
    required this.enunciado,
    required this.tipo,
    this.obrigatoria = false,
    this.opcoes = const [],
    this.ajuda,
  });
}

/// Modelo de anamnese (configurável por especialidade).
class ModeloAnamnese {
  final String id;
  final String nome;
  final String especialidade; // ex.: 'odontologia', 'medicina', 'psicologia'
  final String versao;
  final List<PerguntaAnamnese> perguntas;
  final DateTime criadoEm;
  final String profissionalId;

  const ModeloAnamnese({
    required this.id,
    required this.nome,
    required this.especialidade,
    required this.versao,
    required this.perguntas,
    required this.criadoEm,
    required this.profissionalId,
  });
}

/// Resposta a uma pergunta de anamnese.
class RespostaAnamnese {
  final String perguntaId;
  final String valor; // JSON stringificado

  const RespostaAnamnese({required this.perguntaId, required this.valor});
}

/// Anamnese preenchida para um atendimento.
class Anamnese {
  final String id;
  final String atendimentoId;
  final String modeloId;
  final List<RespostaAnamnese> respostas;
  final DateTime preenchidaEm;
  final String profissionalId;

  const Anamnese({
    required this.id,
    required this.atendimentoId,
    required this.modeloId,
    required this.respostas,
    required this.preenchidaEm,
    required this.profissionalId,
  });
}
        texto: texto,
        dataHora: dataHora,
        assinado: assinado ?? this.assinado,
        assinaturaHash: assinaturaHash ?? this.assinaturaHash,
      );
}
        profissionalId: profissionalId,
        agendamentoId: agendamentoId,
        inicio: inicio,
        fim: fim ?? this.fim,
        status: status ?? this.status,
        observacoesGerais: observacoesGerais ?? this.observacoesGerais,
      );

  bool get encerrado => fim != null && status == StatusAtendimento.atendido;
}
