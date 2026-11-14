import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/widgets/painel_lote_aplicado.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/biomedicina/data/biomedicina_repository.dart';
import 'package:ibn/features/biomedicina/domain/biomedicina.dart';
import 'package:ibn/features/biomedicina/presentation/cubit/biomedicina_cubit.dart';
import 'package:ibn/features/biomedicina/presentation/cubit/biomedicina_state.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

/// Ficha de procedimentos estéticos (RF05.2, RN06), tudo inline.
/// Esta classe só **fornece** o Cubit.
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
  final _scroll = ScrollController();
  final _justAnularCtrl = TextEditingController();
  ProcedimentoEstetico? _retificando; // carregado no painel do topo
  String? _anulandoId; // justificativa aberta dentro do cartão

  bool get _podeEditar =>
      politicaAcesso.podeEditarProcedimentosEsteticos(auth.usuarioLogado!, widget.paciente);

  @override
  void initState() {
    super.initState();
    _justAnularCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _justAnularCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- ações ----------

  /// Registra um procedimento novo ou, com [_retificando], a correção dele.
  Future<String?> _registrar(_Dados r) async {
    final cubit = context.read<BiomedicinaCubit>();
    final base = _retificando;
    final String? erro;
    if (base == null) {
      erro = await cubit.registrar(
        protocolo: r.protocolo,
        protocoloOutro: r.protocoloOutro,
        regiaoTratada: r.regiao,
        parametros: r.parametros,
        insumos: r.insumos,
        observacoes: r.observacoes,
      );
    } else {
      erro = await cubit.retificar(
        base,
        protocolo: r.protocolo,
        protocoloOutro: r.protocoloOutro,
        regiaoTratada: r.regiao,
        parametros: r.parametros,
        insumos: r.insumos,
        observacoes: r.observacoes,
        justificativa: r.justificativa ?? '',
      );
    }
    if (!mounted) return erro;
    _aviso(erro ?? (base == null ? 'Procedimento registrado.' : 'Registro retificado.'));
    if (erro == null && base != null) setState(() => _retificando = null);
    return erro;
  }

  void _carregarRetificar(ProcedimentoEstetico p) {
    setState(() {
      _retificando = p;
      _anulandoId = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _anular(ProcedimentoEstetico p) async {
    final erro = await context.read<BiomedicinaCubit>().anular(p, _justAnularCtrl.text.trim());
    if (!mounted) return;
    _aviso(erro ?? 'Registro anulado.');
    if (erro == null) {
      setState(() {
        _anulandoId = null;
        _justAnularCtrl.clear();
      });
    }
  }

  // ---------- visual ----------

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  Widget _cartao(ProcedimentoEstetico p, bool retificado) {
    final tema = Theme.of(context);
    final riscado = retificado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    final anulando = _anulandoId == p.id;
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
                  TextButton(onPressed: () => _carregarRetificar(p), child: const Text('Retificar')),
                  TextButton(
                    onPressed: () => setState(() {
                      _anulandoId = anulando ? null : p.id;
                      _justAnularCtrl.clear();
                    }),
                    child: Text(anulando ? 'Fechar' : 'Anular'),
                  ),
                ],
              ),
            if (anulando)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('O registro ficará riscado no histórico; nada é apagado (RN05).',
                        style: tema.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _justAnularCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Justificativa (obrigatória)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed:
                          _justAnularCtrl.text.trim().length >= 3 ? () => _anular(p) : null,
                      child: const Text('Confirmar anulação'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(BiomedicinaSuccess s) {
    final tema = Theme.of(context);
    final cubit = context.read<BiomedicinaCubit>();
    return ListView(
      controller: _scroll,
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
                  const Divider(height: 24),
                  _CompositorProcedimento(
                    key: ValueKey(_retificando?.id ?? 'novo'),
                    temAtendimento: cubit.temAtendimentoAberto,
                    base: _retificando,
                    aoRegistrar: _registrar,
                    aoCancelar:
                        _retificando == null ? null : () => setState(() => _retificando = null),
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

// ---------- painel inline ----------

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

/// Procedimento novo ou retificação (quando [base] é informado), em um painel só.
class _CompositorProcedimento extends StatefulWidget {
  final bool temAtendimento;
  final ProcedimentoEstetico? base;
  final Future<String?> Function(_Dados) aoRegistrar;
  final VoidCallback? aoCancelar;

  const _CompositorProcedimento({
    super.key,
    required this.temAtendimento,
    required this.base,
    required this.aoRegistrar,
    this.aoCancelar,
  });

  @override
  State<_CompositorProcedimento> createState() => _CompositorProcedimentoState();
}

class _CompositorProcedimentoState extends State<_CompositorProcedimento> {
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
      (!_retificando || _justCtrl.text.trim().length >= 3) &&
      (_retificando || widget.temAtendimento);

  void _limpar() {
    setState(() {
      _protocolo = TipoProtocolo.peeling;
      _outroCtrl.clear();
      _regiaoCtrl.clear();
      _paramCtrl.clear();
      _obsCtrl.clear();
      _justCtrl.clear();
      _insumos.clear();
    });
  }

  Future<void> _salvar() async {
    final outro = _outroCtrl.text.trim();
    final erro = await widget.aoRegistrar(_Dados(
      protocolo: _protocolo,
      protocoloOutro: _protocolo == TipoProtocolo.outro && outro.isNotEmpty ? outro : null,
      regiao: _regiaoCtrl.text.trim(),
      parametros: _paramCtrl.text.trim(),
      insumos: List.of(_insumos),
      observacoes: _obsCtrl.text.trim(),
      justificativa: _retificando ? _justCtrl.text.trim() : null,
    ));
    if (erro == null && mounted && !_retificando) _limpar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_retificando ? 'Retificar procedimento' : 'Novo procedimento estético',
            style: tema.textTheme.titleMedium),
        if (_retificando)
          Text('O registro anterior ficará riscado no histórico (nada é apagado).',
              style: tema.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final t in TipoProtocolo.values)
              ChoiceChip(
                label: Text(t.rotulo),
                selected: _protocolo == t,
                onSelected: (_) => setState(() => _protocolo = t),
              ),
          ],
        ),
        if (_protocolo == TipoProtocolo.outro) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _outroCtrl,
            decoration: const InputDecoration(
              labelText: 'Descreva o protocolo *',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _regiaoCtrl,
          decoration: const InputDecoration(
            labelText: 'Região tratada *',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _paramCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Parâmetros (ex.: concentração do ácido, profundidade da agulha)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Produto, lote e validade * (RN06)', style: tema.textTheme.titleSmall),
        const SizedBox(height: 6),
        PainelLoteAplicado(aoAdicionar: (l) => setState(() => _insumos.add(l))),
        if (_insumos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _insumos.length; i++)
                InputChip(
                  label: Text(
                    '${_insumos[i].produto} • lote ${_insumos[i].lote} • val. '
                    '${formatarData(_insumos[i].validade)} • ${_num(_insumos[i].quantidade)} '
                    '${_insumos[i].unidade.rotulo}',
                  ),
                  onDeleted: () => setState(() => _insumos.removeAt(i)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _obsCtrl,
          maxLines: 2,
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
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _podeSalvar ? _salvar : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(_retificando ? 'Retificar' : 'Registrar procedimento'),
            ),
            if (_retificando && widget.aoCancelar != null)
              TextButton(onPressed: widget.aoCancelar, child: const Text('Cancelar')),
          ],
        ),
        if (!_retificando && !widget.temAtendimento)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Inicie um atendimento na aba Atendimentos para registrar o procedimento.',
              style: tema.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}