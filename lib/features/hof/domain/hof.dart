import 'dart:typed_data';
import 'package:ibn/core/lote_aplicado.dart';

/// Harmonização Orofacial (RF04.2, RN06). Modelos imutáveis.
/// Registros só de inclusão: para corrigir, cria-se outro com [retificaId] (RN05).

/// Tipo de procedimento. [exigeLote]: lote e validade obrigatórios (RN06).
enum TipoHOF {
  toxinaBotulinica('Toxina botulínica', true),
  preenchimento('Preenchimento facial', true),
  bioestimulador('Bioestimulador de colágeno', true),
  fiosSustentacao('Fios de sustentação', false),
  outro('Outro', false);

  final String rotulo;
  final bool exigeLote;
  const TipoHOF(this.rotulo, this.exigeLote);
}

enum AreaFace {
  testa('Testa'),
  glabela('Glabela'),
  periorbital('Periorbital'),
  nariz('Nariz'),
  malar('Malar'),
  labios('Lábios'),
  perioral('Perioral'),
  mento('Mento'),
  mandibula('Mandíbula'),
  cervical('Região cervical');

  final String rotulo;
  const AreaFace(this.rotulo);
}

enum LadoFace {
  esquerdo('Esquerdo'),
  direito('Direito'),
  bilateral('Bilateral'),
  linhaMedia('Linha média');

  final String rotulo;
  const LadoFace(this.rotulo);
}

/// Um ponto de aplicação (região, lado, quantidade e, se houver, profundidade).
class PontoAplicacao {
  final AreaFace area;
  final LadoFace lado;
  final double quantidade;
  final double? profundidadeMm;
  final String? tecnica;

  const PontoAplicacao({
    required this.area,
    required this.lado,
    required this.quantidade,
    this.profundidadeMm,
    this.tecnica,
  });
}

/// Procedimento de HOF feito dentro de um atendimento.
/// [anulacao] = registro que apenas anula o apontado por [retificaId].
class ProcedimentoHOF {
  final String id;
  final String pacienteId;
  final String atendimentoId;
  final String profissionalId;
  final TipoHOF tipo;
  final String? tipoOutro;
  final List<PontoAplicacao> pontos;
  final List<LoteAplicado> insumos;
  final String? tecnica;
  final String observacoes;
  final DateTime dataHora;
  final String? retificaId;
  final String? justificativa;
  final bool anulacao;

  const ProcedimentoHOF({
    required this.id,
    required this.pacienteId,
    required this.atendimentoId,
    required this.profissionalId,
    required this.tipo,
    this.tipoOutro,
    this.pontos = const [],
    this.insumos = const [],
    this.tecnica,
    this.observacoes = '',
    required this.dataHora,
    this.retificaId,
    this.justificativa,
    this.anulacao = false,
  });

  String get rotuloTipo {
    final o = (tipoOutro ?? '').trim();
    return tipo == TipoHOF.outro && o.isNotEmpty ? o : tipo.rotulo;
  }
}

/// Foto comparativa (antes/depois). Bytes em memória por enquanto.
class FotoComparativaHOF {
  final String id;
  final String pacienteId;
  final DateTime data;
  final String descricao;
  final String nomeArquivo;
  final Uint8List bytes;
  final bool isAntes;
  final String profissionalId;

  const FotoComparativaHOF({
    required this.id,
    required this.pacienteId,
    required this.data,
    required this.descricao,
    required this.nomeArquivo,
    required this.bytes,
    this.isAntes = false,
    required this.profissionalId,
  });
}