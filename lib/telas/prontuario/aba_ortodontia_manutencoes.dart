import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/odontograma.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';
import '../../core/usuario.dart';

/// Widgets da seção **Manutenções Ortodônticas** (Fase F).
class SecaoManutencoes extends StatefulWidget {
  final Paciente paciente;
  final Usuario usuario;
  final List<ManutencaoOrtodontica> manutencoes;
  final bool podeEditar;

  const SecaoManutencoes({
    required this.paciente,
    required this.usuario,
    required this.manutencoes,
    required this.podeEditar,
  });

  @override
  State<SecaoManutencoes> createState() => _SecaoManutencoesState();
}

class _SecaoManutencoesState extends State<SecaoManutencoes> {
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Manutenções Ortodônticas', style: tema.textTheme.titleLarge),
                if (widget.podeEditar)
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Nova manutenção'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.manutencoes.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma manutenção registrada')))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.manutencoes.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) => _linha(widget.manutencoes[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linha(ManutencaoOrtodontica m) {
    final tema = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(m.ativacaoRealizada, style: tema.textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data: ${formatarData(m.data)}'),
          if (m.proximaManutencao != null) Text('Próxima: ${formatarData(m.proximaManutencao!)}', style: const TextStyle(color: Colors.blue)),
          if (m.observacoes?.isNotEmpty == true) Text('Obs: ${m.observacoes}'),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}