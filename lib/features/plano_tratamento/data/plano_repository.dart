import 'package:flutter/foundation.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/odontograma/domain/anatomia_dente.dart';
import 'package:ibn/features/plano_tratamento/domain/orcamento_visibilidade.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';

/// Planos de tratamento em memória (PROVISÓRIO).
///
/// Regras:
/// - só o criador altera o plano (itens, pagamento, encaminhamento);
/// - itens nunca são apagados: o que não será feito fica "Cancelado";
/// - item só nasce "Planejado", e só o encaminhado pode ser realizado pelo
///   executante; o não encaminhado, pelo criador;
/// - RN04: o executante só enxerga a [GuiaProcedimentoExecutante]
///   (`guiasDoExecutante`); os valores só saem pelos métodos do criador.
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class PlanoRepository extends ChangeNotifier {
  final List<PlanoTratamento> _planos = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'pl${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- consultas ----------

  /// Planos do paciente, do mais recente ao mais antigo. [criadorId] limita aos
  /// planos daquela pessoa (é o filtro que protege os valores, RN04).
  List<PlanoTratamento> planosDoPaciente(String pacienteId, {String? criadorId}) => _planos
      .where((p) => p.pacienteId == pacienteId && (criadorId == null || p.criadorId == criadorId))
      .toList()
      .reversed
      .toList();

  PlanoTratamento? planoPorId(String id) {
    for (final p in _planos) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// O que o executante vê: só as guias dos itens encaminhados (ou já feitos) a ele.
  List<GuiaProcedimentoExecutante> guiasDoExecutante(String pacienteId, String executanteId) => [
        for (final p in _planos.reversed)
          if (p.pacienteId == pacienteId)
            for (final i in p.itens)
              if (i.executanteId == executanteId &&
                  (i.status == StatusItem.encaminhado || i.status == StatusItem.realizado))
                orcamentoVisibilidade.gerarGuiaParaExecutante(p, i),
      ];

  bool temHistorico(String pacienteId) => _planos.any((p) => p.pacienteId == pacienteId);

  // ---------- plano ----------

  /// Devolve a mensagem de erro, ou null se criou.
  String? criarPlano(PlanoTratamento p) {
    if (planoPorId(p.id) != null) return 'Plano duplicado.';
    if (p.titulo.trim().isEmpty) return 'Informe o título do plano.';
    if (p.itens.isNotEmpty) return 'Um plano novo começa sem procedimentos.';
    if (p.orcamento != null) return 'Um plano novo começa sem forma de pagamento.';
    _planos.add(p);
    notifyListeners();
    return null;
  }

  /// Plano que o usuário pode alterar, ou o erro.
  (PlanoTratamento?, String?) _doCriador(String planoId, String usuarioId) {
    final p = planoPorId(planoId);
    if (p == null) return (null, 'Plano não encontrado.');
    if (p.criadorId != usuarioId) return (null, 'Só quem criou o plano pode alterá-lo.');
    return (p, null);
  }

  void _salvar(PlanoTratamento novo) {
    final i = _planos.indexWhere((p) => p.id == novo.id);
    _planos[i] = novo;
    notifyListeners();
  }

  String? adicionarItem(String planoId, String usuarioId, ItemPlano item) {
    final (plano, erro) = _doCriador(planoId, usuarioId);
    if (plano == null) return erro;
    if (plano.itens.any((i) => i.id == item.id)) return 'Procedimento duplicado no plano.';
    if (item.status != StatusItem.planejado || item.executanteId != null) {
      return 'Um procedimento novo começa "Planejado" e sem executante.';
    }
    if (buscarProcedimento(item.procedimentoId) == null) return 'Procedimento não encontrado.';
    final dente = item.dente;
    if (dente != null && !AnatomiaDente.ehValido(dente)) return 'Dente $dente inválido.';
    if (item.valorCentavos < 0) return 'O valor não pode ser negativo.';
    if (item.descontoCentavos < 0 || item.descontoCentavos > item.valorCentavos) {
      return 'O desconto deve ficar entre zero e o valor do procedimento.';
    }
    _salvar(plano.copiarCom(itens: [...plano.itens, item]));
    return null;
  }

  String? definirOrcamento(String planoId, String usuarioId, Orcamento o) {
    final (plano, erro) = _doCriador(planoId, usuarioId);
    if (plano == null) return erro;
    if (o.parcelas < 1 || o.parcelas > 12) return 'O número de parcelas deve ficar entre 1 e 12.';
    if (o.parcelas > 1 && o.forma != FormaPagamento.cartaoCredito && o.forma != FormaPagamento.boleto) {
      return 'Só cartão de crédito e boleto podem ser parcelados.';
    }
    _salvar(plano.copiarCom(orcamento: o));
    return null;
  }

  // ---------- itens ----------

  /// Troca o item [itemId] pelo resultado de [alterar]. Devolve o erro, ou null.
  String? _alterarItem(
    PlanoTratamento plano,
    String itemId,
    ItemPlano Function(ItemPlano) alterar,
  ) {
    _salvar(plano.copiarCom(
      itens: [for (final i in plano.itens) i.id == itemId ? alterar(i) : i],
    ));
    return null;
  }

  ItemPlano? _item(PlanoTratamento p, String itemId) {
    for (final i in p.itens) {
      if (i.id == itemId) return i;
    }
    return null;
  }

  /// Encaminha um procedimento planejado a outro profissional, com instruções
  /// clínicas (sem valores). A validação de quem pode ser executante é do Cubit.
  String? encaminharItem(
    String planoId,
    String itemId,
    String usuarioId,
    String executanteId, {
    String? instrucoes,
    DateTime? agora,
  }) {
    final (plano, erro) = _doCriador(planoId, usuarioId);
    if (plano == null) return erro;
    final item = _item(plano, itemId);
    if (item == null) return 'Procedimento não encontrado no plano.';
    if (item.status != StatusItem.planejado) {
      return 'Só procedimentos "Planejado" podem ser encaminhados.';
    }
    if (executanteId == usuarioId) {
      return 'Para executar você mesmo, marque como realizado.';
    }
    final texto = (instrucoes ?? '').trim();
    return _alterarItem(
      plano,
      itemId,
      (i) => i.copiarCom(
        status: StatusItem.encaminhado,
        executanteId: executanteId,
        encaminhadoEm: agora ?? DateTime.now(),
        instrucoes: texto.isEmpty ? null : texto,
      ),
    );
  }

  /// Marca como realizado: o criador, se não foi encaminhado; o executante, se foi.
  String? realizarItem(String planoId, String itemId, String usuarioId, {DateTime? agora}) {
    final plano = planoPorId(planoId);
    if (plano == null) return 'Plano não encontrado.';
    final item = _item(plano, itemId);
    if (item == null) return 'Procedimento não encontrado no plano.';
    switch (item.status) {
      case StatusItem.planejado:
        if (plano.criadorId != usuarioId) {
          return 'Só quem criou o plano executa um procedimento que não foi encaminhado.';
        }
      case StatusItem.encaminhado:
        if (item.executanteId != usuarioId) {
          return 'Só o profissional que recebeu o encaminhamento marca como realizado.';
        }
      case StatusItem.realizado:
        return 'Este procedimento já foi realizado.';
      case StatusItem.cancelado:
        return 'Este procedimento foi cancelado.';
    }
    return _alterarItem(
      plano,
      itemId,
      (i) => i.copiarCom(
        status: StatusItem.realizado,
        realizadoEm: agora ?? DateTime.now(),
        realizadoPorId: usuarioId,
      ),
    );
  }

  String? cancelarItem(String planoId, String itemId, String usuarioId) {
    final (plano, erro) = _doCriador(planoId, usuarioId);
    if (plano == null) return erro;
    final item = _item(plano, itemId);
    if (item == null) return 'Procedimento não encontrado no plano.';
    if (item.status == StatusItem.realizado) return 'Procedimento realizado não pode ser cancelado.';
    if (item.status == StatusItem.cancelado) return 'Este procedimento já está cancelado.';
    return _alterarItem(plano, itemId, (i) => i.copiarCom(status: StatusItem.cancelado));
  }
}

final planoRepository = PlanoRepository();