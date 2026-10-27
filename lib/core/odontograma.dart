import 'package:flutter/foundation.dart';
import 'condicao_odonto.dart';

/// Faces do dente (RF04.1).
enum FaceDente {
  vestibular('Vestibular'),
  lingual('Lingual/Palatina'),
  mesial('Mesial'),
  distal('Distal'),
  oclusal('Oclusal/Incisal');

  final String rotulo;
  const FaceDente(this.rotulo);
}

/// Raízes de um dente (nomes usados no sistema). Em cada dente, a lista de raízes
/// vem de `AnatomiaDente.raizes`.
enum RaizDente {
  unica('Raiz única'),
  vestibular('Raiz vestibular'),
  palatina('Raiz palatina'),
  mesial('Raiz mesial'),
  distal('Raiz distal'),
  mesiovestibular('Raiz mesiovestibular'),
  distovestibular('Raiz distovestibular');

  final String rotulo;
  const RaizDente(this.rotulo);
}

/// Como o odontograma é mostrado.
enum VisaoOdontograma {
  atual('Atual'),
  planejado('Planejado'),
  realizado('Realizado'),
  emData('Em uma data');

  final String rotulo;
  const VisaoOdontograma(this.rotulo);
}

/// Qual arcada do aparelho ortodôntico (Fase E).
enum ArcadaOdonto {
  superior('Superior'),
  inferior('Inferior');

  final String rotulo;
  const ArcadaOdonto(this.rotulo);
}

/// Tipo de marca por arcada (Fase E).
enum TipoMarcaArcada {
  aparelhoFixo('Aparelho fixo'),
  aparelhoMovel('Aparelho móvel / placa'),
  alinhadores('Alinhadores'),
  contencaoRemovivel('Contenção removível'),
  expansor('Expansor');

  final String rotulo;
  const TipoMarcaArcada(this.rotulo);
}

/// Marcação de uma arcada ortodôntica (não vinculada a um dente específico).
/// Registros só de inclusão; retificação via [retificaId] (RN05).
class MarcaArcada {
  final String id;
  final String pacienteId;
  final ArcadaOdonto arcada;
  final TipoMarcaArcada tipo;
  final StatusTratamento status;
  final DateTime data;
  final String profissionalId;
  final String? retificaId;

  const MarcaArcada({
    required this.id,
    required this.pacienteId,
    required this.arcada,
    required this.tipo,
    this.status = StatusTratamento.existente,
    required this.data,
    required this.profissionalId,
    this.retificaId,
  });

  MarcaArcada copiarCom({
    StatusTratamento? status,
    String? retificaId,
  }) =>
      MarcaArcada(
        id: id,
        pacienteId: pacienteId,
        arcada: arcada,
        tipo: tipo,
        status: status ?? this.status,
        data: data,
        profissionalId: profissionalId,
        retificaId: retificaId ?? this.retificaId,
      );
}

/// Numeração FDI (dentição permanente). Ordem de desenho: da direita para a
/// esquerda do paciente, como no odontograma impresso.
const List<int> dentesSuperiores = [18, 17, 16, 15, 14, 13, 12, 11, 21, 22, 23, 24, 25, 26, 27, 28];
const List<int> dentesInferiores = [48, 47, 46, 45, 44, 43, 42, 41, 31, 32, 33, 34, 35, 36, 37, 38];

/// Dentes decíduos (FDI 51–85), mostrados na faixa central quando marcada.
const List<int> deciduosSuperiores = [55, 54, 53, 52, 51, 61, 62, 63, 64, 65];
const List<int> deciduosInferiores = [85, 84, 83, 82, 81, 71, 72, 73, 74, 75];

/// Um registro (evolução) no histórico do odontograma. Registros nunca são
/// apagados nem alterados (rastreabilidade, RN05): para corrigir um erro, cria-se
/// um novo registro que aponta para o errado em [retificaId].
class RegistroDente {
  final String id;
  final String pacienteId;
  final int numeroDente;
  final AlvoOdonto alvo;
  final FaceDente? face; // só quando alvo == face
  final RaizDente? raiz; // só quando alvo == raiz
  final CondicaoOdonto condicao;
  final StatusTratamento status;
  final String? procedimentoId;
  final String observacao;
  final DateTime data;
  final String profissionalId; // pessoa que registrou
  final String? retificaId; // id do registro que este corrige

  const RegistroDente({
    required this.id,
    required this.pacienteId,
    required this.numeroDente,
    required this.alvo,
    this.face,
    this.raiz,
    required this.condicao,
    this.status = StatusTratamento.existente,
    this.procedimentoId,
    this.observacao = '',
    required this.data,
    required this.profissionalId,
    this.retificaId,
  });

  /// Chave do "estado atual":
  /// - numa face vale o último registro da face;
  /// - no dente inteiro e em cada raiz, os **estados** (Ausente, Hígido, Resto
  ///   radicular...) se substituem, e cada outra condição vale uma vez (ex.:
  ///   Coroa, Fratura e Mobilidade convivem; planejado → realizado atualiza a mesma).
  String get chaveEstado {
    final grupo = condicao.categoria == CategoriaCondicao.estado ? 'estado' : condicao.name;
    switch (alvo) {
      case AlvoOdonto.dente:
        return '$numeroDente-dente-$grupo';
      case AlvoOdonto.face:
        return '$numeroDente-face-${face!.name}';
      case AlvoOdonto.raiz:
        return '$numeroDente-raiz-${raiz!.name}-$grupo';
    }
  }

  /// "Nenhum" com [retificaId] só anula o registro apontado.
  bool get ehAnulacao => condicao == CondicaoOdonto.nenhum && retificaId != null;
}

/// A marcação mais importante do dente (menor prioridade): vira o selo.
RegistroDente? marcaPrincipal(List<RegistroDente> marcacoes) {
  RegistroDente? melhor;
  for (final r in marcacoes) {
    if (melhor == null || r.condicao.prioridade < melhor.condicao.prioridade) {
      melhor = r;
    }
  }
  return melhor;
}

/// ====== FASE F — Ortodontia: Ficha e Manutenções ======

/// Tipo de aparelho ortodôntico.
enum TipoAparelhoOrto {
  fixoMetalico('Fixo metálico'),
  fixoEstetico('Fixo estético'),
  autoligado('Autoligado'),
  alinhadores('Alinhadores (ex.: Invisalign)'),
  removivel('Removível / Placa'),
  funcional('Funcional'),
  expansor('Expansor');

  final String rotulo;
  const TipoAparelhoOrto(this.rotulo);
}

/// Arco ortodôntico em uso.
class ArcoOrtodontico {
  final String fio;
  final String calibre;

  const ArcoOrtodontico({required this.fio, required this.calibre});

  ArcoOrtodontico copiarCom({String? fio, String? calibre}) =>
      ArcoOrtodontico(fio: fio ?? this.fio, calibre: calibre ?? this.calibre);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArcoOrtodontico &&
          runtimeType == other.runtimeType &&
          fio == other.fio &&
          calibre == other.calibre;

  @override
  int get hashCode => Object.hash(fio, calibre);
}

/// Elásticos em uso.
class ElasticosOrtodonticos {
  final String descricao;

  const ElasticosOrtodonticos(this.descricao);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElasticosOrtodonticos &&
          runtimeType == other.runtimeType &&
          descricao == other.descricao;

  @override
  int get hashCode => descricao.hashCode;
}

/// Ficha ortodôntica principal (Fase F).
class FichaOrtodontica {
  final String id;
  final String pacienteId;
  final TipoAparelhoOrto tipoAparelho;
  final DateTime dataInstalacao;
  final DateTime? previsaoTermino;
  final String objetivos;
  final String? observacoesGerais;
  final ArcoOrtodontico? arcoSuperior;
  final ArcoOrtodontico? arcoInferior;
  final ElasticosOrtodonticos? elasticosSuperior;
  final ElasticosOrtodonticos? elasticosInferior;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final String profissionalId;

  const FichaOrtodontica({
    required this.id,
    required this.pacienteId,
    required this.tipoAparelho,
    required this.dataInstalacao,
    this.previsaoTermino,
    required this.objetivos,
    this.observacoesGerais,
    this.arcoSuperior,
    this.arcoInferior,
    this.elasticosSuperior,
    this.elasticosInferior,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.profissionalId,
  });

  FichaOrtodontica copiarCom({
    TipoAparelhoOrto? tipoAparelho,
    DateTime? dataInstalacao,
    DateTime? previsaoTermino,
    String? objetivos,
    String? observacoesGerais,
    ArcoOrtodontico? arcoSuperior,
    ArcoOrtodontico? arcoInferior,
    ElasticosOrtodonticos? elasticosSuperior,
    ElasticosOrtodonticos? elasticosInferior,
    DateTime? atualizadoEm,
    String? profissionalId,
  }) =>
      FichaOrtodontica(
        id: id,
        pacienteId: pacienteId,
        tipoAparelho: tipoAparelho ?? this.tipoAparelho,
        dataInstalacao: dataInstalacao ?? this.dataInstalacao,
        previsaoTermino: previsaoTermino ?? this.previsaoTermino,
        objetivos: objetivos ?? this.objetivos,
        observacoesGerais: observacoesGerais ?? this.observacoesGerais,
        arcoSuperior: arcoSuperior ?? this.arcoSuperior,
        arcoInferior: arcoInferior ?? this.arcoInferior,
        elasticosSuperior: elasticosSuperior ?? this.elasticosSuperior,
        elasticosInferior: elasticosInferior ?? this.elasticosInferior,
        criadoEm: criadoEm,
        atualizadoEm: atualizadoEm ?? DateTime.now(),
        profissionalId: profissionalId ?? this.profissionalId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FichaOrtodontica &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          pacienteId == other.pacienteId;

  @override
  int get hashCode => Object.hash(id, pacienteId);
}

/// Uma manutenção ortodôntica (consulta de ativação/ajuste).
class ManutencaoOrtodontica {
  final String id;
  final String pacienteId;
  final DateTime data;
  final String ativacaoRealizada;
  final String? observacoes;
  final DateTime? proximaManutencao;
  final String profissionalId;
  final String? agendamentoId;

  const ManutencaoOrtodontica({
    required this.id,
    required this.pacienteId,
    required this.data,
    required this.ativacaoRealizada,
    this.observacoes,
    this.proximaManutencao,
    required this.profissionalId,
    this.agendamentoId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManutencaoOrtodontica &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          pacienteId == other.pacienteId;

  @override
  int get hashCode => Object.hash(id, pacienteId);
}

/// Foto comparativa ortodôntica (antes/depois).
class FotoComparativaOrto {
  final String id;
  final String pacienteId;
  final DateTime data;
  final String descricao;
  final String caminhoArquivo;
  final bool isAntes;
  final String profissionalId;

  const FotoComparativaOrto({
    required this.id,
    required this.pacienteId,
    required this.data,
    required this.descricao,
    required this.caminhoArquivo,
    this.isAntes = false,
    required this.profissionalId,
  });
}

/// Repository para ficha e manutenções ortodônticas (em memória, PROVISÓRIO).
class OrtodontiaRepository extends ChangeNotifier {
  final List<FichaOrtodontica> _fichas = [];
  final List<ManutencaoOrtodontica> _manutencoes = [];
  final List<FotoComparativaOrto> _fotos = [];
  int _contador = 0;

  OrtodontiaRepository({bool comExemplos = false}) {
    if (comExemplos) _carregarExemplos();
  }

  String novoId() {
    _contador++;
    return 'orto${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- Ficha ----------

  FichaOrtodontica? fichaDoPaciente(String pacienteId) {
    try {
      return _fichas.firstWhere((f) => f.pacienteId == pacienteId);
    } catch (_) {
      return null;
    }
  }

  String? salvarFicha(FichaOrtodontica ficha) {
    final existente = fichaDoPaciente(ficha.pacienteId);
    if (existente != null) {
      final idx = _fichas.indexOf(existente);
      _fichas[idx] = ficha;
    } else {
      _fichas.add(ficha);
    }
    notifyListeners();
    return null;
  }

  // ---------- Manutenções ----------

  List<ManutencaoOrtodontica> manutencoesDoPaciente(String pacienteId) =>
      _manutencoes
          .where((m) => m.pacienteId == pacienteId)
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data));

  String? adicionarManutencao(ManutencaoOrtodontica m) {
    _manutencoes.add(m);
    notifyListeners();
    return null;
  }

  // ---------- Fotos ----------

  List<FotoComparativaOrto> fotosDoPaciente(String pacienteId) =>
      _fotos
          .where((f) => f.pacienteId == pacienteId)
          .toList()
        ..sort((a, b) => a.data.compareTo(b.data));

  String? adicionarFoto(FotoComparativaOrto f) {
    _fotos.add(f);
    notifyListeners();
    return null;
  }

  void _carregarExemplos() {
    // Exemplos serão adicionados quando houver dados de teste
  }
}

final ortodontiaRepository = OrtodontiaRepository();