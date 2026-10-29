import 'package:flutter/material.dart';
import 'package:ibn/features/odontograma/domain/anatomia_dente.dart';
import 'package:ibn/features/odontograma/domain/condicao_odonto.dart';
import 'package:ibn/features/odontograma/domain/odontograma.dart';

/// O que o profissional escolheu no menu: uma condição (registro rápido) ou
/// abrir o formulário completo "Adicionar evolução".
class ResultadoMenu {
  final CondicaoOdonto? condicao;
  final bool pedeEvolucao;

  const ResultadoMenu.escolheu(CondicaoOdonto this.condicao) : pedeEvolucao = false;
  const ResultadoMenu.evolucao()
      : condicao = null,
        pedeEvolucao = true;
}

/// Menu de condições do dente ou da face tocada (usado em janela ou folha inferior).
class MenuCondicoes extends StatelessWidget {
  final int dente;
  final FaceDente? face;
  final RaizDente? raiz;
  final List<RegistroDente> marcacoes; // todas as marcações atuais do dente

  const MenuCondicoes({
    super.key,
    required this.dente,
    required this.face,
    this.raiz,
    required this.marcacoes,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final alvo = raiz != null
        ? AlvoOdonto.raiz
        : (face != null ? AlvoOdonto.face : AlvoOdonto.dente);
    final opcoes = CondicaoOdonto.paraAlvo(
      alvo,
      deciduo: AnatomiaDente.ehDeciduo(dente),
      multirradicular: AnatomiaDente.raizes(dente).length > 1,
    );
    final nome = AnatomiaDente.nomeCompleto(dente);
    final titulo = raiz != null
        ? '$nome • ${raiz!.rotulo}'
        : (face != null ? '$nome • ${face!.rotulo}' : nome);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.titleMedium),
          if (marcacoes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Marcações atuais', style: tema.textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in marcacoes)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: CircleAvatar(backgroundColor: Color(r.condicao.corArgb)),
                    label: Text(
                      '${r.condicao.sigla} • ${r.raiz?.rotulo ?? r.face?.rotulo ?? 'dente'} • ${r.status.rotulo}',
                    ),
                  ),
              ],
            ),
          ],
          const Divider(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final c in opcoes)
                    SizedBox(
                      width: 236,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: c == CondicaoOdonto.nenhum
                            ? const Icon(Icons.block, size: 18)
                            : Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Color(c.corArgb),
                                  border: Border.all(color: Colors.black38, width: 0.6),
                                ),
                              ),
                        title: Text(
                          c == CondicaoOdonto.nenhum
                              ? 'Nenhum (limpar marcações)'
                              : '${c.rotulo} (${c.sigla})',
                        ),
                        onTap: () => Navigator.of(context).pop(ResultadoMenu.escolheu(c)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(const ResultadoMenu.evolucao()),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar evolução'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tocar em uma condição registra como "Existente". Use "Adicionar evolução" para planejar, marcar como realizado ou escrever uma observação.',
            style: tema.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}