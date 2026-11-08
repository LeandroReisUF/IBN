import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/widgets/dialogo_lote_aplicado.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/biomedicina/data/biomedicina_repository.dart';
import 'package:ibn/features/biomedicina/domain/biomedicina.dart';
import 'package:ibn/features/biomedicina/presentation/cubit/biomedicina_cubit.dart';
import 'package:ibn/features/biomedicina/presentation/cubit/biomedicina_state.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

/// Ficha de procedimentos estéticos (RF05.2, RN06). Esta classe só **fornece** o Cubit.
class AbaProcedimentosBiomedicina extends StatelessWidget {
  final Paciente paciente;
  const AbaProcedimentosBiomedicina({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BiomedicinaCubit(
        repositorio: biomedicinaRepository,
        prontuario: prontuarioRepository,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
      )..carregar(),
      child: _View(paciente: paciente),
    );
  }
}

class _View extends StatefulWidget {
  final Paciente paciente;
  const _View({required this.paciente});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  bool get _podeEditar =>
      politicaAcesso.podeEditarProcedimentosEsteticos(auth.usuarioLogado!, widget.paciente);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- ações ----------

  Future<void> _novo() async {
    final cubit = context.read<BiomedicinaCubit>();
    if (!cubit.temAtendimentoAberto) {
      _aviso('Inicie um atendimento na aba Atendimentos antes de registrar o procedimento.');
      return;
    }
    final r = await showDialog<_Dados>(
      context: context,
      builder: (_) => const _DialogoProcedimento(),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.registrar(
      protocolo: r.protocolo,
      protocoloOutro: r.protocoloOutro,
      regiaoTratada: r.regiao,
      parametros: r.parametros,
      insumos: r.insumos,
      observacoes: r.observacoes,
    );
    if (!mounted) return;
    _aviso(erro ?? 'Procedimento registrado.');
  }

  Future<void> _retificar(ProcedimentoEstetico anterior) async {
    final cubit = context.read<BiomedicinaCubit>();
    final r = await showDialog<_Dados>(
      context: context,
      builder: (_) => _DialogoProcedimento(base: anterior),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.retificar(
      anterior,
      protocolo: r.protocolo,
      protocoloOutro: r.protocoloOutro,
      regiaoTratada: r.regiao,
      parametros: r.parametros,
      insumos: r.insumos,
      observacoes: r.observacoes,
      justificativa: r.justificativa ?? '',
    );
    if (!mounted) return;
    _aviso(erro ?? 'Registro retificado.');
  }

  Future<void> _anular(ProcedimentoEstetico anterior) async {
    final cubit = context.read<BiomedicinaCubit>();
    final just = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoJustificativa(),
    );
    if (just == null || !mounted) return;
    final erro = await cubit.anular(anterior, just);
    if (!mounted) return;
    _aviso(erro ?? 'Registro anulado.');
  }

  // ---------- visual ----------

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  Widget _cartao(ProcedimentoEstetico p, bool retificado) {
    final tema = Theme.of(context);
    final riscado = retificado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    final linhas = <String>[
      if (p.anulacao) 'Anulou um registro anterior.',
      if (p.retificaId != null && !p.anulacao) 'Retifica um registro anterior.',
      if (p.retificaId != null) 'Motivo: ${p.justificativa ?? ''}',
      if (p.regiaoTratada.isNotEmpty) 'Região: ${p.regiaoTratada}',
      if (p.parametros.isNotEmpty) 'Parâmetros: ${p.parametros}',
      for (final i in p.insumos)
        '${i.produto}${(i.marca ?? '').isEmpty ? '' : ' (${i.marca})'} • lote ${i.lote} • '
            'val. ${formatarData(i.validade)} • ${_num(i.quantidade)} ${i.unidade.rotulo}',
      if (p.observacoes.isNotEmpty) 'Obs.: ${p.observacoes}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${p.anulacao ? 'Anulação' : p.rotuloProtocolo} • ${_dataHora(p.dataHora)}',
                    style: tema.textTheme.titleSmall?.copyWith(
                      decoration: retificado ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (retificado) const Chip(label: Text('Retificado')),
              ],
            ),
            const SizedBox(height: 6),
            for (final l in linhas) Text(l, style: riscado),
            if (_podeEditar && !retificado && !p.anulacao)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: () => _retificar(p), child: const Text('Retificar')),
                  TextButton(onPressed: () => _anular(p), child: const Text('Anular')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(BiomedicinaSuccess s) {
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
                Text('Procedimentos estéticos', style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Você vê apenas os registros feitos por você. O procedimento é registrado dentro '
                  'de um atendimento em aberto, com ao menos um produto com lote e validade (RN06). '
                  'Nada é apagado: use Retificar ou Anular (RN05).',
                  style: tema.textTheme.bodySmall,
                ),
                if (_podeEditar) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _novo,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo procedimento'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (s.procedimentos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum procedimento registrado.')),
          )
        else
          for (final p in s.procedimentos) _cartao(p, s.retificados.contains(p.id)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BiomedicinaCubit, BiomedicinaState>(
      builder: (context, state) => switch (state) {
        BiomedicinaInitial() || BiomedicinaLoading() => const Center(child: CircularProgressIndicator()),
        BiomedicinaError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<BiomedicinaCubit>().carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        final BiomedicinaSuccess s => _conteudo(s),
      },
    );
  }
}

// ---------- diálogos ----------

class _Dados {
  final TipoProtocolo protocolo;
  final String? protocoloOutro;
  final String regiao;
  final String parametros;
  final List<LoteAplicado> insumos;
  final String observacoes;
  final String? justificativa;

  const _Dados({
    required this.protocolo,
    required this.protocoloOutro,
    required this.regiao,
    required this.parametros,
    required this.insumos,
    required this.observacoes,
    required this.justificativa,
  });
}

/// Procedimento novo, ou retificação quando [base] é informado.
class _DialogoProcedimento extends StatefulWidget {
  final ProcedimentoEstetico? base;
  const _DialogoProcedimento({this.base});

  @override
  State<_DialogoProcedimento> createState() => _DialogoProcedimentoState();
}

class _DialogoProcedimentoState extends State<_DialogoProcedimento> {
  late TipoProtocolo _protocolo;
  final _outroCtrl = TextEditingController();
  final _regiaoCtrl = TextEditingController();
  final _paramCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  final List<LoteAplicado> _insumos = [];

  bool get _retificando => widget.base != null;

  @override
  void initState() {
    super.initState();
    final b = widget.base;
    _protocolo = b?.protocolo ?? TipoProtocolo.peeling;
    if (b != null) {
      _outroCtrl.text = b.protocoloOutro ?? '';
      _regiaoCtrl.text = b.regiaoTratada;
      _paramCtrl.text = b.parametros;
      _obsCtrl.text = b.observacoes;
      _insumos.addAll(b.insumos);
    }
    for (final c in [_outroCtrl, _regiaoCtrl, _justCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _outroCtrl.dispose();
    _regiaoCtrl.dispose();
    _paramCtrl.dispose();
    _obsCtrl.dispose();
    _justCtrl.dispose();
    super.dispose();
  }

  bool get _podeSalvar =>
      _regiaoCtrl.text.trim().isNotEmpty &&
      _insumos.isNotEmpty &&
      (_protocolo != TipoProtocolo.outro || _outroCtrl.text.trim().isNotEmpty) &&
      (!_retificando || _justCtrl.text.trim().length >= 3);

  Future<void> _addInsumo() async {
    final i = await showDialog<LoteAplicado>(
      context: context,
      builder: (_) => const DialogoLoteAplicado(),
    );
    if (i != null) setState(() => _insumos.add(i));
  }

  void _salvar() {
    final outro = _outroCtrl.text.trim();
    Navigator.of(context).pop(_Dados(
      protocolo: _protocolo,
      protocoloOutro: _protocolo == TipoProtocolo.outro && outro.isNotEmpty ? outro : null,
      regiao: _regiaoCtrl.text.trim(),
      parametros: _paramCtrl.text.trim(),
      insumos: List.of(_insumos),
      observacoes: _obsCtrl.text.trim(),
      justificativa: _retificando ? _justCtrl.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(_retificando ? 'Retificar procedimento' : 'Novo procedimento estético'),
      content: SizedBox(
        width: 480,
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
              DropdownButtonFormField<TipoProtocolo>(
                initialValue: _protocolo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Protocolo *', border: OutlineInputBorder()),
                items: [
                  for (final t in TipoProtocolo.values) DropdownMenuItem(value: t, child: Text(t.rotulo)),
                ],
                onChanged: (v) => setState(() => _protocolo = v ?? _protocolo),
              ),
              if (_protocolo == TipoProtocolo.outro) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _outroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descreva o protocolo *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _regiaoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Região tratada *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paramCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Parâmetros (ex.: concentração do ácido, profundidade da agulha)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Produto, lote e validade * (RN06)', style: tema.textTheme.titleSmall),
              for (var i = 0; i < _insumos.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${_insumos[i].produto} • lote ${_insumos[i].lote}'),
                  subtitle: Text(
                    'Val. ${formatarData(_insumos[i].validade)} • '
                    '${_num(_insumos[i].quantidade)} ${_insumos[i].unidade.rotulo}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remover produto (ainda não registrado)',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _insumos.removeAt(i)),
                  ),
                ),
              TextButton.icon(
                onPressed: _addInsumo,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Adicionar produto / lote'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
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
          child: Text(_retificando ? 'Retificar' : 'Registrar'),
        ),
      ],
    );
  }
}

class _DialogoJustificativa extends StatefulWidget {
  const _DialogoJustificativa();

  @override
  State<_DialogoJustificativa> createState() => _DialogoJustificativaState();
}

class _DialogoJustificativaState extends State<_DialogoJustificativa> {
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
    return AlertDialog(
      title: const Text('Anular registro'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('O registro ficará riscado no histórico; nada é apagado (RN05).'),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Justificativa (obrigatória)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ctrl.text.trim().length >= 3 ? () => Navigator.of(context).pop(_ctrl.text.trim()) : null,
          child: const Text('Anular'),
        ),
      ],
    );
  }
}