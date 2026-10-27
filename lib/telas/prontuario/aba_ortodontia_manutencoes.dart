import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/odontograma.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';
import '../../core/usuario.dart';
import '../agenda/tela_form_agendamento.dart';

class SecaoManutencoes extends StatefulWidget {
  final Paciente paciente;
  final Usuario usuario;
  final List<ManutencaoOrtodontica> manutencoes;
  final bool podeEditar;

  const SecaoManutencoes({
    super.key,
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
                if (widget.podeEditar) ...[
                  FilledButton.icon(
                    onPressed: () => _abrirDialogo(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova manutenção'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _agendarManutencao(),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Agendar manutenção'),
                  ),
                ],
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
          if (m.proximaManutencao != null)
            Text('Próxima: ${formatarData(m.proximaManutencao!)}', style: const TextStyle(color: Colors.blue)),
          if (m.observacoes?.isNotEmpty == true) Text('Obs: ${m.observacoes}'),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _abrirDialogo(manutencao: m),
    );
  }

  void _abrirDialogo({ManutencaoOrtodontica? manutencao}) {
    final editando = manutencao != null;
    final ativacaoCtrl = TextEditingController(text: manutencao?.ativacaoRealizada ?? '');
    final obsCtrl = TextEditingController(text: manutencao?.observacoes ?? '');
    DateTime data = manutencao?.data ?? DateTime.now();
    DateTime? proxima = manutencao?.proximaManutencao;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editando ? 'Editar manutenção' : 'Nova manutenção'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ativacaoCtrl,
                decoration: const InputDecoration(labelText: 'Ativação realizada *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: obsCtrl,
                decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _campoData('Data da manutenção *', data, (d) => data = d),
              const SizedBox(height: 12),
              _campoData('Próxima manutenção (opcional)', proxima, (d) => proxima = d, opcional: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (ativacaoCtrl.text.trim().isEmpty) return;
              final nova = ManutencaoOrtodontica(
                id: manutencao?.id ?? ortodontiaRepository.novoId(),
                pacienteId: widget.paciente.id,
                data: data,
                ativacaoRealizada: ativacaoCtrl.text.trim(),
                observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                proximaManutencao: proxima,
                profissionalId: widget.usuario.id,
                agendamentoId: manutencao?.agendamentoId,
              );
              ortodontiaRepository.adicionarManutencao(nova);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(editando ? 'Manutenção atualizada' : 'Manutenção adicionada')),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _campoData(String label, DateTime? valor, ValueChanged<DateTime> onChange, {bool opcional = false}) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: valor ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (d != null) onChange(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label + (opcional ? ' (opcional)' : ' *'),
          border: const OutlineInputBorder(),
        ),
        child: Text(valor != null ? formatarData(valor) : 'Toque para escolher'),
      ),
    );
  }

  void _agendarManutencao() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TelaFormAgendamento(dataInicial: DateTime.now())),
    );
  }
}