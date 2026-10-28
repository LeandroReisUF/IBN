import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/presentation/cubit/agendamento_cubit.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/ortodontia.dart';
import 'package:ibn/core/paciente.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/agenda/presentation/pages/tela_form_agendamento.dart';

/// Seção **Manutenções Ortodônticas**. Só inclusão: "Retificar" cria um novo
/// registro e deixa o anterior riscado (RN05). Não existe excluir.
class SecaoManutencoes extends StatefulWidget {
  final Paciente paciente;
  final Usuario usuario;
  final List<ManutencaoOrtodontica> manutencoes;
  final Set<String> retificadas;
  final bool podeEditar;

  const SecaoManutencoes({
    super.key,
    required this.paciente,
    required this.usuario,
    required this.manutencoes,
    required this.retificadas,
    required this.podeEditar,
  });

  @override
  State<SecaoManutencoes> createState() => _SecaoManutencoesState();
}

class _SecaoManutencoesState extends State<SecaoManutencoes> {
  Future<void> _abrirDialogo({ManutencaoOrtodontica? retificando}) async {
    final resultado = await showDialog<ManutencaoOrtodontica>(
      context: context,
      builder: (_) => _DialogoManutencao(
        pacienteId: widget.paciente.id,
        profissionalId: widget.usuario.id,
        retificando: retificando,
      ),
    );
    if (resultado == null || !mounted) return;

    final mensagem = ScaffoldMessenger.of(context);
    final erro = ortodontiaRepository.adicionarManutencao(resultado);
    if (erro != null) {
      mensagem.showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    logsAcesso.registrar(
      usuarioId: widget.usuario.id,
      acao: resultado.retificaId == null ? 'registrou_manutencao_orto' : 'retificou_manutencao_orto',
      entidade: 'paciente',
      entidadeId: widget.paciente.id,
    );
    mensagem.showSnackBar(SnackBar(
      content: Text(resultado.retificaId == null ? 'Manutenção registrada.' : 'Manutenção retificada.'),
    ));
  }

  /// Abre o agendamento já com paciente, procedimento e profissional.
    void _agendar() {
    final usuario = widget.usuario;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => AgendamentoCubit(servico: agenda, usuario: usuario),
          child: TelaFormAgendamento(
            dataInicial: soData(DateTime.now()),
            pacienteIdInicial: widget.paciente.id,
            procedimentoIdInicial: 'manutencao-ortodontica',
            profissionalIdInicial: usuario.id,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manutenções ortodônticas', style: tema.textTheme.titleLarge),
                if (widget.podeEditar) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _abrirDialogo(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nova manutenção'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _agendar,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: const Text('Agendar manutenção'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (widget.manutencoes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma manutenção registrada.'),
                  )
                else
                  for (final m in widget.manutencoes) ...[
                    const Divider(height: 1),
                    _linha(m),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _linha(ManutencaoOrtodontica m) {
    final retificada = widget.retificadas.contains(m.id);
    final riscado = retificada ? const TextStyle(decoration: TextDecoration.lineThrough) : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(m.ativacaoRealizada, style: riscado),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data: ${formatarData(m.data)}', style: riscado),
          if (m.proximaManutencao != null)
            Text('Próxima: ${formatarData(m.proximaManutencao!)}', style: riscado),
          if ((m.observacoes ?? '').isNotEmpty) Text('Obs.: ${m.observacoes}', style: riscado),
          if (m.retificaId != null) Text('Retifica um registro anterior. Motivo: ${m.justificativa ?? ''}'),
        ],
      ),
      trailing: retificada
          ? const Chip(label: Text('Retificada'))
          : (widget.podeEditar
              ? TextButton(onPressed: () => _abrirDialogo(retificando: m), child: const Text('Retificar'))
              : null),
    );
  }
}

/// Diálogo de nova manutenção ou retificação. É um widget com estado próprio:
/// assim a data escolhida aparece na hora (o diálogo antigo não atualizava).
class _DialogoManutencao extends StatefulWidget {
  final String pacienteId;
  final String profissionalId;
  final ManutencaoOrtodontica? retificando;

  const _DialogoManutencao({
    required this.pacienteId,
    required this.profissionalId,
    this.retificando,
  });

  @override
  State<_DialogoManutencao> createState() => _DialogoManutencaoState();
}

class _DialogoManutencaoState extends State<_DialogoManutencao> {
  final _ativacaoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  late DateTime _data;
  DateTime? _proxima;

  bool get _retificando => widget.retificando != null;

  @override
  void initState() {
    super.initState();
    final r = widget.retificando;
    _data = r?.data ?? soData(DateTime.now());
    _proxima = r?.proximaManutencao;
    _ativacaoCtrl.text = r?.ativacaoRealizada ?? '';
    _obsCtrl.text = r?.observacoes ?? '';
    for (final c in [_ativacaoCtrl, _justCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _ativacaoCtrl.dispose();
    _obsCtrl.dispose();
    _justCtrl.dispose();
    super.dispose();
  }

  String? get _erroProxima =>
      (_proxima != null && _proxima!.isBefore(_data)) ? 'Deve ser depois da data da manutenção' : null;

  bool get _podeSalvar =>
      _ativacaoCtrl.text.trim().isNotEmpty &&
      _erroProxima == null &&
      (!_retificando || _justCtrl.text.trim().length >= 3);

  Future<void> _escolherData({required bool proxima}) async {
    final atual = proxima ? (_proxima ?? _data) : _data;
    final nova = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (nova == null) return;
    setState(() {
      if (proxima) {
        _proxima = soData(nova);
      } else {
        _data = soData(nova);
      }
    });
  }

  void _salvar() {
    final obs = _obsCtrl.text.trim();
    Navigator.of(context).pop(
      ManutencaoOrtodontica(
        id: ortodontiaRepository.novoId(),
        pacienteId: widget.pacienteId,
        data: _data,
        ativacaoRealizada: _ativacaoCtrl.text.trim(),
        observacoes: obs.isEmpty ? null : obs,
        proximaManutencao: _proxima,
        profissionalId: widget.profissionalId,
        agendamentoId: widget.retificando?.agendamentoId,
        retificaId: widget.retificando?.id,
        justificativa: _retificando ? _justCtrl.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(_retificando ? 'Retificar manutenção' : 'Nova manutenção'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_retificando)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'O registro anterior ficará riscado no histórico (nada é apagado).',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              TextField(
                controller: _ativacaoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ativação realizada *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _escolherData(proxima: false),
                icon: const Icon(Icons.event_outlined),
                label: Text('Data da manutenção: ${formatarData(_data)}'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _escolherData(proxima: true),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(_proxima == null
                          ? 'Próxima manutenção (opcional)'
                          : 'Próxima: ${formatarData(_proxima!)}'),
                    ),
                  ),
                  if (_proxima != null)
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: () => setState(() => _proxima = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (_erroProxima != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_erroProxima!, style: TextStyle(color: tema.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_retificando) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _justCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Justificativa da retificação (obrigatória)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _podeSalvar ? _salvar : null,
          child: Text(_retificando ? 'Retificar' : 'Salvar'),
        ),
      ],
    );
  }
}