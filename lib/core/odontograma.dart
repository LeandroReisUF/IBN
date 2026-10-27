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