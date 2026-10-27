import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/odontograma.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';
import '../../core/usuario.dart';

/// Widgets da seção **Arcos e Elásticos** (Fase F).
class SecaoArcosElasticos extends StatelessWidget {
  final FichaOrtodontica? ficha;
  final bool podeEditar;
  final VoidCallback onEditarFicha;

  const SecaoArcosElasticos({
    required this.ficha,
    required this.podeEditar,
    required this.onEditarFicha,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Arcos e Elásticos Atuais', style: tema.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _card(context, 'Superior', ficha?.arcoSuperior, ficha?.elasticosSuperior)),
                const SizedBox(width: 12),
                Expanded(child: _card(context, 'Inferior', ficha?.arcoInferior, ficha?.elasticosInferior)),
              ],
            ),
            if (podeEditar) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onEditarFicha,
                icon: const Icon(Icons.edit),
                label: const Text('Editar arcos/elásticos (na ficha acima)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String titulo, ArcoOrtodontico? arco, ElasticosOrtodonticos? elasticos) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _linha('Fio', arco?.fio ?? '—'),
            _linha('Calibre', arco?.calibre ?? '—'),
            const Divider(height: 16),
            _linha('Elásticos', elasticos?.descricao ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _linha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}