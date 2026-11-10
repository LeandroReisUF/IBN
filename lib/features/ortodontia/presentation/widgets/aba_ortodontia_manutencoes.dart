import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/presentation/cubit/agendamento_cubit.dart';
import 'package:ibn/features/agenda/presentation/pages/tela_form_agendamento.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/ortodontia/domain/ortodontia.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';

/// Aba **Manutenções**: painel compacto no topo (sem janela) e a lista abaixo.
/// Só inclusão: "Retificar" carrega o registro no painel e cria um novo,
/// deixando o anterior riscado (RN05). Não existe excluir.
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
  final _ativacaoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  DateTime _data = soData(DateTime.now());
  DateTime? _proxima;
  ManutencaoOrtodontica? _retificando;

  @override
  void initState() {
    super.initState();
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

  // ---------- painel ----------

  String? get _erroProxima =>
      (_proxima != null && _proxima!.isBefore(_data)) ? 'Deve ser depois da data da manutenção' : null;

  bool get _podeSalvar =>
      _ativacaoCtrl.text.trim().isNotEmpty &&
      _erroProxima == null &&
      (_retificando == null || _justCtrl.text.trim().length >= 3);

  void _limpar() {
    setState(() {
      _retificando = null;
      _data = soData(DateTime.now());
      _proxima = null;
      _ativacaoCtrl.clear();
      _obsCtrl.clear();
      _justCtrl.clear();
    });
  }

  void _carregarParaRetificar(ManutencaoOrtodontica m) {
    setState(() {
      _retificando = m;
      _data = m.data;
      _proxima = m.proximaManutencao;
      _ativacaoCtrl.text = m.ativacaoRealizada;
      _obsCtrl.text = m.observacoes ?? '';
      _justCtrl.clear();
    });
  }

  Future<void> _escolherData({required bool proxima}) async {
    final atual = proxima ? (_proxima ?? _data) : _data;
    final nova = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (nova == null || !mounted) return;
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
    final r = _retificando;
    final nova = ManutencaoOrtodontica(
      id: ortodontiaRepository.novoId(),
      pacienteId: widget.paciente.id,
      data: _data,
      ativacaoRealizada: _ativacaoCtrl.text.trim(),
      observacoes: obs.isEmpty ? null : obs,
      proximaManutencao: _proxima,
      profissionalId: widget.usuario.id,
      agendamentoId: r?.agendamentoId,
      retificaId: r?.id,
      justificativa: r == null ? null : _justCtrl.text.trim(),
    );
    final mensagem = ScaffoldMessenger.of(context);
    final erro = ortodontiaRepository.adicionarManutencao(nova);
    if (erro != null) {
      mensagem.showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    logsAcesso.registrar(
      usuarioId: widget.usuario.id,
      acao: r == null ? 'registrou_manutencao_orto' : 'retificou_manutencao_orto',
      entidade: 'paciente',
      entidadeId: widget.paciente.id,
    );
    _limpar();
    mensagem.showSnackBar(
      SnackBar(content: Text(r == null ? 'Manutenção registrada.' : 'Manutenção retificada.')),
    );
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

  // ---------- visual ----------

  Widget _painel(Widget filho) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(child: Padding(padding: const EdgeInsets.all(16), child: filho)),
        ),
      );

  Widget _painelNovo() {
    final tema = Theme.of(context);
    final retificando = _retificando != null;
    return _painel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retificando ? 'Retificar manutenção' : 'Nova manutenção',
              style: tema.textTheme.titleMedium),
          if (retificando)
            Text('O registro anterior ficará riscado no histórico (nada é apagado).',
                style: tema.textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _ativacaoCtrl,
            decoration: const InputDecoration(
              labelText: 'Ativação realizada *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _escolherData(proxima: false),
                icon: const Icon(Icons.event_outlined),
                label: Text('Data: ${formatarData(_data)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _escolherData(proxima: true),
                icon: const Icon(Icons.event_available_outlined),
                label: Text(_proxima == null
                    ? 'Próxima (opcional)'
                    : 'Próxima: ${formatarData(_proxima!)}'),
              ),
              if (_proxima != null)
                IconButton(
                  tooltip: 'Limpar a próxima',
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
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
          ),
          if (retificando) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _justCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Justificativa da retificação *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _podeSalvar ? _salvar : null,
                icon: const Icon(Icons.save_outlined),
                label: Text(retificando ? 'Retificar' : 'Registrar manutenção'),
              ),
              if (retificando) TextButton(onPressed: _limpar, child: const Text('Cancelar')),
              OutlinedButton.icon(
                onPressed: _agendar,
                icon: const Icon(Icons.calendar_today_outlined),
                label: const Text('Agendar manutenção'),
              ),
            ],
          ),
        ],
      ),
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
              ? TextButton(onPressed: () => _carregarParaRetificar(m), child: const Text('Retificar'))
              : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.podeEditar) ...[
          _painelNovo(),
          const SizedBox(height: 8),
        ],
        _painel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Histórico de manutenções', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (widget.manutencoes.isEmpty)
                const Text('Nenhuma manutenção registrada.')
              else
                for (final m in widget.manutencoes) ...[
                  const Divider(height: 1),
                  _linha(m),
                ],
            ],
          ),
        ),
      ],
    );
  }
}