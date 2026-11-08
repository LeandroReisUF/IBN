import 'package:ibn/core/lote_aplicado.dart';

/// Biomedicina estética, Sala 4 (RF05.2, RN06). Modelos imutáveis.
/// Registros só de inclusão: para corrigir, cria-se outro com [retificaId] (RN05).

enum TipoProtocolo {
  peeling('Peeling'),
  microagulhamento('Microagulhamento'),
  intradermoterapia('Intradermoterapia'),
  outro('Outro');

  final String rotulo;
  const TipoProtocolo(this.rotulo);
}

/// Procedimento estético feito dentro de um atendimento.
/// [insumos]: produtos aplicados, com lote e validade obrigatórios (RN06).
/// [anulacao] = registro que apenas anula o apontado por [retificaId].
class ProcedimentoEstetico {
  final String id;
  final String pacienteId;
  final String atendimentoId;
  final String profissionalId;
  final TipoProtocolo protocolo;
  final String? protocoloOutro;
  final String regiaoTratada;
  final String parametros; // ex.: concentração do ácido, profundidade da agulha
  final List<LoteAplicado> insumos;
  final String observacoes;
  final DateTime dataHora;
  final String? retificaId;
  final String? justificativa;
  final bool anulacao;

  const ProcedimentoEstetico({
    required this.id,
    required this.pacienteId,
    required this.atendimentoId,
    required this.profissionalId,
    required this.protocolo,
    this.protocoloOutro,
    this.regiaoTratada = '',
    this.parametros = '',
    this.insumos = const [],
    this.observacoes = '',
    required this.dataHora,
    this.retificaId,
    this.justificativa,
    this.anulacao = false,
  });

  String get rotuloProtocolo {
    final o = (protocoloOutro ?? '').trim();
    return protocolo == TipoProtocolo.outro && o.isNotEmpty ? o : protocolo.rotulo;
  }
}