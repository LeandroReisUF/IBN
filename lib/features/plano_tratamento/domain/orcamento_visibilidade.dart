import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';

/// RN04: quem pode ver valores, descontos e pagamento de um plano, e como o
/// executante recebe só a especificação clínica.
///
/// ATENÇÃO: no app isto só decide o que mostrar. No servidor a mesma regra
/// precisa valer na API (o executante nunca deve receber os valores).
class OrcamentoVisibilidadeService {
  /// Só o criador do plano e o Administrador.
  bool podeVerValores(Usuario usuario, PlanoTratamento plano) =>
      usuario.perfil == Perfil.administrador || usuario.id == plano.criadorId;

  /// Monta a guia do executante a partir de um item. [item] precisa ter executante.
  GuiaProcedimentoExecutante gerarGuiaParaExecutante(PlanoTratamento plano, ItemPlano item) =>
      GuiaProcedimentoExecutante(
        planoId: plano.id,
        itemId: item.id,
        pacienteId: plano.pacienteId,
        procedimentoId: item.procedimentoId,
        dente: item.dente,
        instrucoes: item.instrucoes,
        status: item.status,
        executanteId: item.executanteId!,
        encaminhadoEm: item.encaminhadoEm,
        realizadoEm: item.realizadoEm,
      );
}

final orcamentoVisibilidade = OrcamentoVisibilidadeService();