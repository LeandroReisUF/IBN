import 'package:ibn/features/exames/domain/exames.dart';

/// Resultado laboratorial estruturado de um exame (RF05.3).
/// Só inclusão (RN05): para corrigir, cria-se outro com [retificaId] e justificativa.
/// [dados] traz analito, valor, unidade e referência; `dados.foraDoPadrao` gera o alerta.
class ResultadoExame {
  final String id;
  final String exameId;
  final String pacienteId;
  final ResultadoLab dados;
  final String profissionalId;
  final DateTime registradoEm;
  final String? retificaId;
  final String? justificativa;

  const ResultadoExame({
    required this.id,
    required this.exameId,
    required this.pacienteId,
    required this.dados,
    required this.profissionalId,
    required this.registradoEm,
    this.retificaId,
    this.justificativa,
  });
}