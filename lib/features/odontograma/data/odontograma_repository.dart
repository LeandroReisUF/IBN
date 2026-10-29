import 'package:flutter/foundation.dart';
import 'package:ibn/features/odontograma/domain/anatomia_dente.dart';
import 'package:ibn/features/odontograma/domain/condicao_odonto.dart';
import 'package:ibn/features/odontograma/domain/odontograma.dart';

/// Guarda os registros do odontograma em memória (PROVISÓRIO).
class OdontogramaRepository extends ChangeNotifier {
  final List<RegistroDente> _registros = [];
  final List<MarcaArcada> _marcasArcada = [];
  int _contador = 0;

  OdontogramaRepository({bool comExemplos = true}) {
    if (comExemplos) _registros.addAll(_exemplos());
  }

  String novoId() {
    _contador++;
    return 'o${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  RegistroDente? _porId(String id) {
    for (final r in _registros) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Ids dos registros que já foram corrigidos por outro registro.
  Set<String> retificados(String pacienteId) => {
        for (final r in _registros)
          if (r.pacienteId == pacienteId && r.retificaId != null) r.retificaId!,
      };

  /// Estado do odontograma de um paciente.
  ///
  /// Vale o ÚLTIMO registro de cada chave ([RegistroDente.chaveEstado]),
  /// ignorando os registros retificados. "Nenhum" limpa as marcações do alvo.
  /// [ate] mostra o odontograma como estava naquela data; [visao] filtra por status.
  Map<String, RegistroDente> estadoAtual(
    String pacienteId, {
    VisaoOdontograma visao = VisaoOdontograma.atual,
    DateTime? ate,
  }) {
    final registros = _registros
        .where((r) => r.pacienteId == pacienteId && (ate == null || !r.data.isAfter(ate)))
        .toList();
    final anulados = {
      for (final r in registros)
        if (r.retificaId != null) r.retificaId!,
    };

    final mapa = <String, RegistroDente>{};
    for (final r in registros) {
      if (anulados.contains(r.id)) continue;
      if (r.condicao == CondicaoOdonto.nenhum) {
        if (!r.ehAnulacao) _limpar(mapa, r);
        continue;
      }
      mapa[r.chaveEstado] = r;
    }

    if (visao == VisaoOdontograma.planejado) {
      mapa.removeWhere((_, r) =>
          r.status != StatusTratamento.planejado && r.status != StatusTratamento.emAndamento);
    } else if (visao == VisaoOdontograma.realizado) {
      mapa.removeWhere((_, r) => r.status != StatusTratamento.realizado);
    }
    return mapa;
  }

  void _limpar(Map<String, RegistroDente> mapa, RegistroDente r) {
    switch (r.alvo) {
      case AlvoOdonto.dente:
        mapa.removeWhere((k, _) => k.startsWith('${r.numeroDente}-dente-'));
      case AlvoOdonto.face:
        mapa.remove('${r.numeroDente}-face-${r.face!.name}');
      case AlvoOdonto.raiz:
        mapa.removeWhere((k, _) => k.startsWith('${r.numeroDente}-raiz-${r.raiz!.name}-'));
    }
  }

  /// Histórico completo, do mais recente para o mais antigo.
  List<RegistroDente> historicoDoPaciente(String pacienteId) =>
      _registros.where((r) => r.pacienteId == pacienteId).toList().reversed.toList();

  /// Só existe "adicionar": não há editar nem excluir (rastreabilidade, RN05).
  /// Devolve a mensagem de erro, ou null se deu certo.
  String? adicionar(RegistroDente r) {
    final erro = _validar(r);
    if (erro != null) return erro;
    _registros.add(r);
    notifyListeners();
    return null;
  }

  String? _validar(RegistroDente r) {
    if (!AnatomiaDente.ehValido(r.numeroDente)) return 'Dente ${r.numeroDente} inválido.';
    if (!r.condicao.alvos.contains(r.alvo)) {
      return '"${r.condicao.rotulo}" não se aplica a ${r.alvo.rotulo.toLowerCase()}.';
    }

    switch (r.alvo) {
      case AlvoOdonto.dente:
        if (r.face != null || r.raiz != null) {
          return 'A marcação do dente inteiro não tem face nem raiz.';
        }
      case AlvoOdonto.face:
        if (r.face == null) return 'Escolha a face.';
        if (r.raiz != null) return 'A marcação de face não tem raiz.';
      case AlvoOdonto.raiz:
        if (r.raiz == null) return 'Escolha a raiz.';
        if (r.face != null) return 'A marcação de raiz não tem face.';
        if (!AnatomiaDente.raizes(r.numeroDente).contains(r.raiz)) {
          return 'O dente ${r.numeroDente} não tem a ${r.raiz!.rotulo.toLowerCase()}.';
        }
    }

    if (r.condicao.soDeciduo && !AnatomiaDente.ehDeciduo(r.numeroDente)) {
      return '"${r.condicao.rotulo}" só se aplica a dentes decíduos.';
    }
    if (r.condicao.soMultirradicular && AnatomiaDente.raizes(r.numeroDente).length < 2) {
      return '"${r.condicao.rotulo}" só se aplica a dentes com mais de uma raiz.';
    }
    if (!r.condicao.usaStatus && r.status != StatusTratamento.existente) {
      return 'A condição "${r.condicao.rotulo}" não usa status.';
    }

    final alvoDaCorrecao = r.retificaId;
    if (alvoDaCorrecao != null) {
      final anterior = _porId(alvoDaCorrecao);
      if (anterior == null || anterior.pacienteId != r.pacienteId) {
        return 'Registro a retificar não encontrado.';
      }
      if (_registros.any((x) => x.retificaId == alvoDaCorrecao)) {
        return 'Este registro já foi retificado.';
      }
      if (anterior.numeroDente != r.numeroDente ||
          anterior.alvo != r.alvo ||
          anterior.face != r.face ||
          anterior.raiz != r.raiz) {
        return 'A retificação deve ser do mesmo dente e do mesmo alvo.';
      }
    } else if (_porId(r.id) != null) {
      return 'Registro duplicado.';
    }
    return null;
  }

  List<RegistroDente> _exemplos() {
    // Exemplos: Maria (p1), João Pedro (p2, 12 anos) e Carlos (p4), atendidos pelo Dr. Davi (id 3).
    RegistroDente ex(
      String id,
      String paciente,
      int dente,
      CondicaoOdonto cond, {
      FaceDente? face,
      RaizDente? raiz,
      StatusTratamento status = StatusTratamento.existente,
      String? proc,
      String obs = '',
      required DateTime data,
    }) =>
        RegistroDente(
          id: id,
          pacienteId: paciente,
          numeroDente: dente,
          alvo: raiz != null
              ? AlvoOdonto.raiz
              : (face != null ? AlvoOdonto.face : AlvoOdonto.dente),
          face: face,
          raiz: raiz,
          condicao: cond,
          status: status,
          procedimentoId: proc,
          observacao: obs,
          data: data,
          profissionalId: '3',
        );
    return [
      ex('o1', 'p1', 16, CondicaoOdonto.restaurado,
          face: FaceDente.oclusal, proc: 'restauracao',
          obs: 'Restauração antiga em resina', data: DateTime(2026, 9, 2)),
      ex('o2', 'p1', 36, CondicaoOdonto.ausente,
          obs: 'Extraído há anos', data: DateTime(2026, 9, 2)),
      ex('o3', 'p1', 26, CondicaoOdonto.cariado,
          face: FaceDente.oclusal, obs: 'Cárie identificada', data: DateTime(2026, 9, 2)),
      ex('o4', 'p1', 26, CondicaoOdonto.restaurado,
          face: FaceDente.oclusal, status: StatusTratamento.planejado,
          proc: 'restauracao', obs: 'Restauração planejada', data: DateTime(2026, 9, 2)),
      ex('o5', 'p1', 11, CondicaoOdonto.restaurado,
          face: FaceDente.vestibular, status: StatusTratamento.realizado,
          proc: 'restauracao', data: DateTime(2026, 10, 1)),
      ex('o6', 'p1', 21, CondicaoOdonto.coroa,
          obs: 'Coroa metalocerâmica', data: DateTime(2026, 9, 2)),
      ex('o7', 'p4', 46, CondicaoOdonto.cariado,
          face: FaceDente.oclusal, data: DateTime(2026, 10, 10)),
      // Raízes (Fase C)
      ex('o8', 'p1', 26, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.mesiovestibular, status: StatusTratamento.realizado,
          obs: 'Canal mesiovestibular concluído', data: DateTime(2026, 9, 20)),
      ex('o9', 'p1', 16, CondicaoOdonto.lesaoPeriapical,
          raiz: RaizDente.palatina, obs: 'Imagem radiolúcida no ápice', data: DateTime(2026, 9, 2)),
      ex('o10', 'p4', 46, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.mesial, status: StatusTratamento.emAndamento,
          data: DateTime(2026, 10, 12)),
      // Decíduos (Fase D): João Pedro, 12 anos (dentição mista)
      ex('o11', 'p2', 54, CondicaoOdonto.cariado,
          face: FaceDente.oclusal, data: DateTime(2026, 10, 5)),
      ex('o12', 'p2', 64, CondicaoOdonto.pulpotomia,
          status: StatusTratamento.realizado, obs: 'Pulpotomia concluída',
          data: DateTime(2026, 10, 5)),
    ];
  }

  // ---------- Marcas de arcada (Fase E) ----------

  /// Marcações ortodônticas de arcada ativas (últimas de cada (arcada, tipo)).
  /// "Ativa" = não retificada nem anulada.
    /// Ids de marcas de arcada já corrigidas por outra (desmarcadas).
  Set<String> _marcasRetificadas(String pacienteId) => {
        for (final m in _marcasArcada)
          if (m.pacienteId == pacienteId && m.retificaId != null) m.retificaId!,
      };

  /// A marca ativa de (arcada, tipo): não é uma retificação e não foi retificada.
  MarcaArcada? marcaAtiva(String pacienteId, ArcadaOdonto arcada, TipoMarcaArcada tipo) {
    final retificadas = _marcasRetificadas(pacienteId);
    for (final m in _marcasArcada.reversed) {
      if (m.pacienteId == pacienteId &&
          m.arcada == arcada &&
          m.tipo == tipo &&
          m.retificaId == null &&
          !retificadas.contains(m.id)) {
        return m;
      }
    }
    return null;
  }

  Map<ArcadaOdonto, List<TipoMarcaArcada>> marcasArcadaAtivas(String pacienteId) {
    return {
      for (final arcada in ArcadaOdonto.values)
        arcada: [
          for (final tipo in TipoMarcaArcada.values)
            if (marcaAtiva(pacienteId, arcada, tipo) != null) tipo,
        ],
    };
  }

  /// Histórico completo de marcas de arcada (do mais recente ao mais antigo).
  List<MarcaArcada> historicoMarcasArcada(String pacienteId) =>
      _marcasArcada
          .where((m) => m.pacienteId == pacienteId)
          .toList()
          .reversed
          .toList();

  String? adicionarMarcaArcada(MarcaArcada m) {
    _marcasArcada.add(m);
    notifyListeners();
    return null;
  }
}

final odontogramas = OdontogramaRepository();