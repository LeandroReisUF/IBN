import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';
import 'package:ibn/features/prontuario/presentation/cubit/atendimentos_cubit.dart';
import 'package:ibn/features/prontuario/presentation/cubit/atendimentos_state.dart';

/// Atendimentos do paciente: cada profissional vê só os que ele mesmo registrou.
/// Fluxo: iniciar → evoluções (rascunho) → assinar → encerrar. Depois de
/// assinada, a evolução só se corrige por adendo (RN05).
/// Esta classe só **fornece** o Cubit; o desenho está em [_AtendimentosView].
class AbaProntuario extends StatelessWidget {
  final Paciente paciente;
  const AbaProntuario({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AtendimentosCubit(
        repositorio: prontuarioRepository,
        agendaService: agenda,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
      )..carregar(),
      child: _AtendimentosView(paciente: paciente),
    );
  }
}

class _AtendimentosView extends StatefulWidget {
  final Paciente paciente;
  const _AtendimentosView({required this.paciente});

  @override
  State<_AtendimentosView> createState() => _AtendimentosViewState();
}

class _AtendimentosViewState extends State<_AtendimentosView> {
  Paciente get _paciente => widget.paciente;
  Usuario get _usuario => auth.usuarioLogado!;
  bool get _podeEditar => politicaAcesso.podeAcessarProntuario(_usuario, _paciente);
  AtendimentosCubit get _cubit => context.read<AtendimentosCubit>();

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Mostra o erro (se houver) vindo de uma ação do Cubit.
  void _mostrarErro(String? erro) {
    if (erro != null && mounted) _aviso(erro);
  }

  // ---------- ações ----------

  Future<void> _iniciar() async {
    final cubit = _cubit;
    final candidatos = cubit.agendamentosIniciaveisHoje();

    String? agendamentoId;
    if (candidatos.isNotEmpty) {
      // '' = atendimento sem agendamento; null = fechou o diálogo (cancela).
      final escolha = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Vincular a um agendamento de hoje?'),
          children: [
            for (final c in candidatos)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(c.id),
                child: Text('${formatarHora(c.inicio)} – ${formatarHora(c.fim)}  •  ${c.status.rotulo}'),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Sem agendamento'),
            ),
          ],
        ),
      );
      if (escolha == null || !mounted) return;
      agendamentoId = escolha.isEmpty ? null : escolha;
    }
    _mostrarErro(await cubit.iniciar(agendamentoId: agendamentoId));
  }

  Future<void> _encerrar(Atendimento a) async {
    final cubit = _cubit;
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoTexto(
        titulo: 'Encerrar atendimento',
        rotulo: 'Observações de encerramento (opcional)',
        obrigatorio: false,
        textoBotao: 'Encerrar',
        aviso: 'Depois de encerrado, nada neste atendimento pode ser alterado (RN05).',
      ),
    );
    if (obs == null || !mounted) return;
    _mostrarErro(await cubit.encerrar(a.id, observacoes: obs));
  }

  Future<void> _novaEvolucao(Atendimento a) async {
    final cubit = _cubit;
    final r = await showDialog<({TipoEvolucao tipo, String texto})>(
      context: context,
      builder: (_) => const _DialogoEvolucao(),
    );
    if (r == null || !mounted) return;
    _mostrarErro(await cubit.adicionarEvolucao(a.id, r.tipo, r.texto));
  }

  Future<void> _editar(Evolucao e) async {
    final cubit = _cubit;
    final r = await showDialog<({TipoEvolucao tipo, String texto})>(
      context: context,
      builder: (_) => _DialogoEvolucao(editando: e),
    );
    if (r == null || !mounted) return;
    _mostrarErro(await cubit.atualizarRascunho(e, r.texto));
  }

  Future<void> _assinar(Evolucao e) async {
    _mostrarErro(await _cubit.assinar(e));
  }

  Future<void> _descartar(Evolucao e) async {
    final cubit = _cubit;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar rascunho?'),
        content: const Text('Só rascunhos podem ser descartados. Evoluções assinadas nunca são apagadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    _mostrarErro(await cubit.descartarRascunho(e));
  }

  Future<void> _adendo(Evolucao e) async {
    final cubit = _cubit;
    final r = await showDialog<({String justificativa, String texto})>(
      context: context,
      builder: (_) => const _DialogoAdendo(),
    );
    if (r == null || !mounted) return;
    _mostrarErro(await cubit.adicionarAdendo(e, r.justificativa, r.texto));
  }

  // ---------- visual ----------

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  Widget _linhaEvolucao(EvolucaoComAdendos item, bool atendimentoEncerrado) {
    final tema = Theme.of(context);
    final e = item.evolucao;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(e.assinada ? 'Assinada' : 'Rascunho'),
                avatar: Icon(e.assinada ? Icons.verified_outlined : Icons.edit_note, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${e.tipo.rotulo} • ${_dataHora(e.dataHora)}'
                  '${e.selo == null ? '' : ' • selo ${e.selo}'}',
                  style: tema.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(e.texto),
          if (_podeEditar)
            Wrap(
              spacing: 8,
              children: [
                if (!e.assinada && !atendimentoEncerrado) ...[
                  TextButton(onPressed: () => _editar(e), child: const Text('Editar')),
                  TextButton(onPressed: () => _assinar(e), child: const Text('Assinar')),
                  TextButton(onPressed: () => _descartar(e), child: const Text('Descartar')),
                ],
                if (e.assinada)
                  TextButton(onPressed: () => _adendo(e), child: const Text('Adicionar adendo')),
              ],
            ),
          for (final a in item.adendos)
            Container(
              margin: const EdgeInsets.only(left: 16, top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adendo • ${_dataHora(a.dataHora)} • selo ${a.selo ?? '—'}',
                      style: tema.textTheme.bodySmall),
                  Text('Motivo: ${a.justificativa}', style: tema.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(a.texto),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartaoAtendimento(AtendimentoDetalhe d) {
    final a = d.atendimento;
    final fim = a.fim == null ? '' : ' – ${formatarHora(a.fim!)}';
    return Card(
      child: ExpansionTile(
        initiallyExpanded: !a.encerrado,
        title: Text('${formatarData(a.inicio)} • ${formatarHora(a.inicio)}$fim'),
        subtitle: Text(a.status.rotulo),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_podeEditar && !a.encerrado)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _novaEvolucao(a),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova evolução'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _encerrar(a),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Encerrar atendimento'),
                ),
              ],
            ),
          if (d.evolucoes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhuma evolução neste atendimento.'),
            )
          else
            for (final item in d.evolucoes) ...[
              const Divider(),
              _linhaEvolucao(item, a.encerrado),
            ],
          if (a.encerrado && (a.observacoesEncerramento ?? '').isNotEmpty) ...[
            const Divider(),
            Text('Encerramento: ${a.observacoesEncerramento}'),
          ],
        ],
      ),
    );
  }

  Widget _cabecalho(bool temAtivo) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Atendimentos', style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Você vê apenas os atendimentos registrados por você. '
              'Evolução assinada não pode ser alterada: use adendo (RN05).',
              style: tema.textTheme.bodySmall,
            ),
            if (_podeEditar) ...[
              const SizedBox(height: 12),
              if (!temAtivo)
                FilledButton.icon(
                  onPressed: _iniciar,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar atendimento'),
                )
              else
                const Text('Há um atendimento em aberto abaixo.'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AtendimentosCubit, AtendimentosState>(
      builder: (context, state) => switch (state) {
        AtendimentosInitial() || AtendimentosLoading() =>
          const Center(child: CircularProgressIndicator()),
        AtendimentosError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _cubit.carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        AtendimentosSuccess(:final atendimentos, :final temAtivo) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _cabecalho(temAtivo),
              if (atendimentos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Nenhum atendimento registrado.')),
                )
              else
                for (final d in atendimentos) _cartaoAtendimento(d),
            ],
          ),
      },
    );
  }
}

// ---------- diálogos ----------

/// Evolução nova ou edição de rascunho (tipo + texto).
class _DialogoEvolucao extends StatefulWidget {
  final Evolucao? editando;
  const _DialogoEvolucao({this.editando});

  @override
  State<_DialogoEvolucao> createState() => _DialogoEvolucaoState();
}

class _DialogoEvolucaoState extends State<_DialogoEvolucao> {
  final _textoCtrl = TextEditingController();
  late TipoEvolucao _tipo;

  @override
  void initState() {
    super.initState();
    _tipo = widget.editando?.tipo ?? TipoEvolucao.livre;
    _textoCtrl.text = widget.editando?.texto ?? '';
    _textoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando != null;
    return AlertDialog(
      title: Text(editando ? 'Editar rascunho' : 'Nova evolução'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TipoEvolucao>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                items: [
                  for (final t in TipoEvolucao.values) DropdownMenuItem(value: t, child: Text(t.rotulo)),
                ],
                // O tipo não muda na edição (só o texto do rascunho).
                onChanged: editando ? null : (v) => setState(() => _tipo = v ?? _tipo),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textoCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Texto da evolução *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _textoCtrl.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop((tipo: _tipo, texto: _textoCtrl.text.trim())),
          child: const Text('Salvar rascunho'),
        ),
      ],
    );
  }
}

/// Adendo: justificativa + texto.
class _DialogoAdendo extends StatefulWidget {
  const _DialogoAdendo();

  @override
  State<_DialogoAdendo> createState() => _DialogoAdendoState();
}

class _DialogoAdendoState extends State<_DialogoAdendo> {
  final _justCtrl = TextEditingController();
  final _textoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _justCtrl.addListener(() => setState(() {}));
    _textoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _justCtrl.dispose();
    _textoCtrl.dispose();
    super.dispose();
  }

  bool get _ok => _justCtrl.text.trim().length >= 3 && _textoCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar adendo'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'O adendo é datado e assinado na hora, e a evolução original continua intacta.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _justCtrl,
                decoration: const InputDecoration(
                  labelText: 'Justificativa *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textoCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Texto do adendo *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ok
              ? () => Navigator.of(context).pop(
                    (justificativa: _justCtrl.text.trim(), texto: _textoCtrl.text.trim()),
                  )
              : null,
          child: const Text('Assinar adendo'),
        ),
      ],
    );
  }
}

/// Diálogo de um único campo de texto (usado ao encerrar o atendimento).
class _DialogoTexto extends StatefulWidget {
  final String titulo;
  final String rotulo;
  final bool obrigatorio;
  final String textoBotao;
  final String? aviso;

  const _DialogoTexto({
    required this.titulo,
    required this.rotulo,
    required this.obrigatorio,
    required this.textoBotao,
    this.aviso,
  });

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = !widget.obrigatorio || _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.aviso != null) ...[
              Text(widget.aviso!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: widget.rotulo, border: const OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: ok ? () => Navigator.of(context).pop(_ctrl.text.trim()) : null,
          child: Text(widget.textoBotao),
        ),
      ],
    );
  }
}