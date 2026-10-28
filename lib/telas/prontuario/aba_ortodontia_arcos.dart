import 'package:flutter/material.dart';
import 'package:ibn/core/ortodontia.dart';

/// Seção **Arcos e Elásticos**: mostra o que está na ficha. A edição é feita na
/// aba Ficha (os campos ficam lá, junto da versão salva).
class SecaoArcosElasticos extends StatelessWidget {
  final FichaOrtodontica? ficha;
  final bool podeEditar;

  const SecaoArcosElasticos({
    super.key,
    required this.ficha,
    required this.podeEditar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final f = ficha;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Arcos e elásticos atuais', style: tema.textTheme.titleLarge),
                const SizedBox(height: 16),
                if (f == null)
                  const Text('Crie a ficha ortodôntica para registrar arcos e elásticos.')
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _cartao(context, 'Superior', f.arcoSuperior, f.elasticosSuperior),
                      _cartao(context, 'Inferior', f.arcoInferior, f.elasticosInferior),
                    ],
                  ),
                if (podeEditar) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => DefaultTabController.of(context).animateTo(0),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(f == null ? 'Ir para a ficha' : 'Alterar na ficha'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cartao(BuildContext context, String titulo, ArcoOrtodontico? arco,
      ElasticosOrtodonticos? elasticos) {
    final tema = Theme.of(context);
    return SizedBox(
      width: 280,
      child: Card(
        color: tema.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              _linha('Fio', arco?.fio),
              _linha('Calibre', arco?.calibre),
              const Divider(height: 16),
              _linha('Elásticos', elasticos?.descricao),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String? valor) {
    final texto = (valor == null || valor.isEmpty) ? '—' : valor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}