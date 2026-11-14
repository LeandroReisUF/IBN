import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/selecao_arquivo.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/hof/data/hof_repository.dart';
import 'package:ibn/features/hof/domain/hof.dart';
import 'package:ibn/features/hof/presentation/cubit/hof_cubit.dart';
import 'package:ibn/features/hof/presentation/cubit/hof_state.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

double? _lerNumero(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

/// Harmonização Orofacial (RF04.2, RN06), tudo inline. Esta classe só **fornece** o Cubit.
class AbaHof extends StatelessWidget {
  final Paciente paciente;
  const AbaHof({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HofCubit(
        repositorio: hofRepository,
        prontuario: prontuarioRepository,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
      )..carregar(),
      child: _HofView(paciente: paciente),
    );
  }
}

class _HofView extends StatefulWidget {
  final Paciente paciente;
  const _HofView({required this.paciente});

  @override
  State<_HofView> createState() => _HofViewState();
}

class _HofViewState extends State<_HofView> {
  final _scroll = ScrollController();
  final _justAnularCtrl = TextEditingController();
  ProcedimentoHOF? _retificando; // carregado no painel do topo
  String? _anulandoId; // justificativa aberta dentro do cartão

  bool get _podeEditar =>
      politicaAcesso.podeEditarHof(auth.usuarioLogado!, widget.paciente);

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
  Future<String?> _registrar(_DadosProcedimento r) async {
    final cubit = context.read<HofCubit>();
    final base = _retificando;
    final String? erro;
    if (base == null) {
      erro = await cubit.registrar(
        tipo: r.tipo,
        tipoOutro: r.tipoOutro,
        pontos: r.pontos,
        insumos: r.insumos,
        tecnica: r.tecnica,
        observacoes: r.observacoes,
      );
    } else {
      erro = await cubit.retificar(
        base,
        tipo: r.tipo,
        tipoOutro: r.tipoOutro,
        pontos: r.pontos,
        insumos: r.insumos,
        tecnica: r.tecnica,
        observacoes: r.observacoes,
        justificativa: r.justificativa ?? '',
      );
    }
    if (!mounted) return erro;
    _aviso(erro ?? (base == null ? 'Procedimento registrado.' : 'Registro retificado.'));
    if (erro == null && base != null) setState(() => _retificando = null);
    return erro;
  }

  void _carregarRetificar(ProcedimentoHOF p) {
    setState(() {
      _retificando = p;
      _anulandoId = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _anular(ProcedimentoHOF p) async {
    final erro = await context.read<HofCubit>().anular(p, _justAnularCtrl.text.trim());
    if (!mounted) return;
    _aviso(erro ?? 'Registro anulado.');
    if (erro == null) {
      setState(() {
        _anulandoId = null;
        _justAnularCtrl.clear();
      });
    }
  }

  Future<String?> _adicionarFoto(String descricao, bool isAntes, ArquivoSelecionado a) async {
    final erro = await context.read<HofCubit>().adicionarFoto(
          descricao: descricao,
          isAntes: isAntes,
          nomeArquivo: a.nome,
          bytes: a.bytes,
        );
    if (mounted) _aviso(erro ?? 'Foto adicionada.');
    return erro;
  }

  void _ampliar(FotoComparativaHOF f) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(child: Image.memory(f.bytes, fit: BoxFit.contain)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text('${f.descricao} • ${formatarData(f.data)}')),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- visual ----------

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  Widget _cartaoProcedimento(ProcedimentoHOF p, bool retificado) {
    final tema = Theme.of(context);
    final riscado = retificado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    final anulando = _anulandoId == p.id;
    final linhas = <String>[
      if (p.anulacao) 'Anulou um registro anterior.',
      if (p.retificaId != null && !p.anulacao) 'Retifica um registro anterior.',
      if (p.retificaId != null) 'Motivo: ${p.justificativa ?? ''}',
      for (final x in p.pontos)
        '${x.area.rotulo} (${x.lado.rotulo}) • ${_num(x.quantidade)}'
            '${x.profundidadeMm == null ? '' : ' • ${_num(x.profundidadeMm!)} mm'}'
            '${(x.tecnica ?? '').isEmpty ? '' : ' • ${x.tecnica}'}',
      for (final i in p.insumos)
        '${i.produto}${(i.marca ?? '').isEmpty ? '' : ' (${i.marca})'} • lote ${i.lote} • '
            'val. ${formatarData(i.validade)} • ${_num(i.quantidade)} ${i.unidade.rotulo}',
      if ((p.tecnica ?? '').isNotEmpty) 'Técnica: ${p.tecnica}',
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
                    '${p.anulacao ? 'Anulação' : p.rotuloTipo} • ${_dataHora(p.dataHora)}',
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
                  TextButton(
                    onPressed: () => _carregarRetificar(p),
                    child: const Text('Retificar'),
                  ),
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

  Widget _miniatura(FotoComparativaHOF f) {
    final tema = Theme.of(context);
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: () => _ampliar(f),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  f.bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(f.descricao,
                style: tema.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(formatarData(f.data), style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _grupoFotos(String titulo, List<FotoComparativaHOF> lista) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(titulo, style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          Text('Nenhuma foto.', style: tema.textTheme.bodySmall)
        else
          Wrap(spacing: 12, runSpacing: 12, children: [for (final f in lista) _miniatura(f)]),
      ],
    );
  }

  Widget _conteudo(HofSuccess s) {
    final tema = Theme.of(context);
    final cubit = context.read<HofCubit>();
    final antes = s.fotos.where((f) => f.isAntes).toList();
    final depois = s.fotos.where((f) => !f.isAntes).toList();

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
                Text('Harmonização orofacial', style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Você vê apenas os registros feitos por você. O procedimento é registrado '
                  'dentro de um atendimento em aberto. Lote e validade são obrigatórios para '
                  'toxina, preenchimento e bioestimulador (RN06). Nada é apagado: use Retificar '
                  'ou Anular (RN05).',
                  style: tema.textTheme.bodySmall,
                ),
                if (_podeEditar) ...[
                  const Divider(height: 24),
                  _CompositorHof(
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
        Text('Procedimentos', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (s.procedimentos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhum procedimento registrado.'),
          )
        else
          for (final p in s.procedimentos) _cartaoProcedimento(p, s.retificados.contains(p.id)),
        const SizedBox(height: 16),
        Text('Fotos antes e depois', style: tema.textTheme.titleMedium),
        if (_podeEditar) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _CompositorFoto(aoAdicionar: _adicionarFoto),
            ),
          ),
        ],
        _grupoFotos('Antes', antes),
        _grupoFotos('Depois / acompanhamento', depois),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HofCubit, HofState>(
      builder: (context, state) => switch (state) {
        HofInitial() || HofLoading() => const Center(child: CircularProgressIndicator()),
        HofError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<HofCubit>().carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        final HofSuccess s => _conteudo(s),
      },
    );
  }
}

// ---------- painéis inline ----------

class _DadosProcedimento {
  final TipoHOF tipo;
  final String? tipoOutro;
  final List<PontoAplicacao> pontos;
  final List<LoteAplicado> insumos;
  final String? tecnica;
  final String observacoes;
  final String? justificativa;

  const _DadosProcedimento({
    required this.tipo,
    required this.tipoOutro,
    required this.pontos,
    required this.insumos,
    required this.tecnica,
    required this.observacoes,
    required this.justificativa,
  });
}

/// Procedimento novo ou retificação (quando [base] é informado), em um painel só.
class _CompositorHof extends StatefulWidget {
  final bool temAtendimento;
  final ProcedimentoHOF? base;
  final Future<String?> Function(_DadosProcedimento) aoRegistrar;
  final VoidCallback? aoCancelar;

  const _CompositorHof({
    super.key,
    required this.temAtendimento,
    required this.base,
    required this.aoRegistrar,
    this.aoCancelar,
  });

  @override
  State<_CompositorHof> createState() => _CompositorHofState();
}

class _CompositorHofState extends State<_CompositorHof> {
  late TipoHOF _tipo;
  final _outroCtrl = TextEditingController();
  final _tecnicaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  final List<PontoAplicacao> _pontos = [];
  final List<LoteAplicado> _insumos = [];

  // ponto em preparo
  AreaFace _area = AreaFace.testa;
  LadoFace _lado = LadoFace.bilateral;
  final _qtdPontoCtrl = TextEditingController();
  final _profCtrl = TextEditingController();
  final _tecPontoCtrl = TextEditingController();

  // produto em preparo
  final _produtoCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _qtdInsumoCtrl = TextEditingController();
  UnidadeInsumo _unidade = UnidadeInsumo.unidades;
  DateTime? _validade;
  String? _erroInsumo;

  bool get _retificando => widget.base != null;

  List<TextEditingController> get _todos => [
        _outroCtrl, _tecnicaCtrl, _obsCtrl, _justCtrl, _qtdPontoCtrl, _profCtrl,
        _tecPontoCtrl, _produtoCtrl, _marcaCtrl, _loteCtrl, _qtdInsumoCtrl,
      ];

  @override
  void initState() {
    super.initState();
    final b = widget.base;
    _tipo = b?.tipo ?? TipoHOF.toxinaBotulinica;
    if (b != null) {
      _outroCtrl.text = b.tipoOutro ?? '';
      _tecnicaCtrl.text = b.tecnica ?? '';
      _obsCtrl.text = b.observacoes;
      _pontos.addAll(b.pontos);
      _insumos.addAll(b.insumos);
    }
    for (final c in [_outroCtrl, _justCtrl, _qtdPontoCtrl, _produtoCtrl, _loteCtrl, _qtdInsumoCtrl]) {
      c.addListener(() => setState(() => _erroInsumo = null));
    }
  }

  @override
  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- pontos e produtos ----------

  bool get _pontoOk => (_lerNumero(_qtdPontoCtrl.text) ?? 0) > 0;

  void _addPonto() {
    final q = _lerNumero(_qtdPontoCtrl.text);
    if (q == null || q <= 0) return;
    final tec = _tecPontoCtrl.text.trim();
    setState(() {
      _pontos.add(PontoAplicacao(
        area: _area,
        lado: _lado,
        quantidade: q,
        profundidadeMm: _lerNumero(_profCtrl.text),
        tecnica: tec.isEmpty ? null : tec,
      ));
      _qtdPontoCtrl.clear();
      _profCtrl.clear();
      _tecPontoCtrl.clear();
    });
  }

  bool get _insumoOk =>
      _produtoCtrl.text.trim().isNotEmpty &&
      _loteCtrl.text.trim().isNotEmpty &&
      _validade != null &&
      (_lerNumero(_qtdInsumoCtrl.text) ?? 0) > 0;

  Future<void> _escolherValidade() async {
    final nova = await showDatePicker(
      context: context,
      initialDate: _validade ?? soData(DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (nova != null) {
      setState(() {
        _validade = soData(nova);
        _erroInsumo = null;
      });
    }
  }

  void _addInsumo() {
    final marca = _marcaCtrl.text.trim();
    final lote = LoteAplicado(
      produto: _produtoCtrl.text.trim(),
      marca: marca.isEmpty ? null : marca,
      lote: _loteCtrl.text.trim(),
      validade: _validade!,
      quantidade: _lerNumero(_qtdInsumoCtrl.text)!,
      unidade: _unidade,
    );
    final erro = lote.validar(DateTime.now()); // lote vencido é recusado já aqui (RN06)
    if (erro != null) {
      setState(() => _erroInsumo = erro);
      return;
    }
    setState(() {
      _insumos.add(lote);
      _produtoCtrl.clear();
      _marcaCtrl.clear();
      _loteCtrl.clear();
      _qtdInsumoCtrl.clear();
      _validade = null;
      _erroInsumo = null;
    });
  }

  // ---------- salvar ----------

  bool get _podeSalvar =>
      _pontos.isNotEmpty &&
      (_tipo != TipoHOF.outro || _outroCtrl.text.trim().isNotEmpty) &&
      (!_tipo.exigeLote || _insumos.isNotEmpty) &&
      (!_retificando || _justCtrl.text.trim().length >= 3) &&
      (_retificando || widget.temAtendimento);

  void _limpar() {
    setState(() {
      _tipo = TipoHOF.toxinaBotulinica;
      for (final c in _todos) {
        c.clear();
      }
      _pontos.clear();
      _insumos.clear();
      _validade = null;
      _erroInsumo = null;
      _area = AreaFace.testa;
      _lado = LadoFace.bilateral;
      _unidade = UnidadeInsumo.unidades;
    });
  }

  Future<void> _salvar() async {
    String? limpo(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final erro = await widget.aoRegistrar(_DadosProcedimento(
      tipo: _tipo,
      tipoOutro: _tipo == TipoHOF.outro ? limpo(_outroCtrl) : null,
      pontos: List.of(_pontos),
      insumos: List.of(_insumos),
      tecnica: limpo(_tecnicaCtrl),
      observacoes: _obsCtrl.text.trim(),
      justificativa: _retificando ? _justCtrl.text.trim() : null,
    ));
    if (erro == null && mounted && !_retificando) _limpar();
  }

  // ---------- visual ----------

  Widget _campo(TextEditingController c, String rotulo, {double largura = 150, bool numero = false}) =>
      SizedBox(
        width: largura,
        child: TextField(
          controller: c,
          keyboardType: numero ? const TextInputType.numberWithOptions(decimal: true) : null,
          inputFormatters:
              numero ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
          decoration: InputDecoration(
            labelText: rotulo,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_retificando ? 'Retificar procedimento' : 'Novo procedimento',
            style: tema.textTheme.titleMedium),
        if (_retificando)
          Text('O registro anterior ficará riscado no histórico (nada é apagado).',
              style: tema.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final t in TipoHOF.values)
              ChoiceChip(
                label: Text(t.rotulo),
                selected: _tipo == t,
                onSelected: (_) => setState(() => _tipo = t),
              ),
          ],
        ),
        if (_tipo == TipoHOF.outro) ...[
          const SizedBox(height: 12),
          _campo(_outroCtrl, 'Descreva o procedimento *', largura: 340),
        ],

        // ----- pontos de aplicação -----
        const SizedBox(height: 16),
        Text('Pontos de aplicação *', style: tema.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<AreaFace>(
                initialValue: _area,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Região', isDense: true, border: OutlineInputBorder()),
                items: [
                  for (final a in AreaFace.values) DropdownMenuItem(value: a, child: Text(a.rotulo)),
                ],
                onChanged: (v) => setState(() => _area = v ?? _area),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<LadoFace>(
                initialValue: _lado,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Lado', isDense: true, border: OutlineInputBorder()),
                items: [
                  for (final l in LadoFace.values) DropdownMenuItem(value: l, child: Text(l.rotulo)),
                ],
                onChanged: (v) => setState(() => _lado = v ?? _lado),
              ),
            ),
            _campo(_qtdPontoCtrl, 'Quantidade *', largura: 120, numero: true),
            _campo(_profCtrl, 'Prof. (mm)', largura: 100, numero: true),
            _campo(_tecPontoCtrl, 'Técnica', largura: 150),
            FilledButton.tonalIcon(
              onPressed: _pontoOk ? _addPonto : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Adicionar ponto'),
            ),
          ],
        ),
        if (_pontos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _pontos.length; i++)
                InputChip(
                  label: Text(
                    '${_pontos[i].area.rotulo} (${_pontos[i].lado.rotulo}) • ${_num(_pontos[i].quantidade)}',
                  ),
                  onDeleted: () => setState(() => _pontos.removeAt(i)),
                ),
            ],
          ),
        ],

        // ----- produto, lote e validade -----
        const SizedBox(height: 16),
        Text(
          _tipo.exigeLote ? 'Produto, lote e validade * (RN06)' : 'Produto, lote e validade',
          style: tema.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _campo(_produtoCtrl, 'Produto *', largura: 190),
            _campo(_marcaCtrl, 'Marca', largura: 140),
            _campo(_loteCtrl, 'Lote *', largura: 110),
            OutlinedButton.icon(
              onPressed: _escolherValidade,
              icon: const Icon(Icons.event_outlined),
              label: Text(_validade == null ? 'Validade *' : formatarData(_validade!)),
            ),
            _campo(_qtdInsumoCtrl, 'Qtd. usada *', largura: 110, numero: true),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<UnidadeInsumo>(
                initialValue: _unidade,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                items: [
                  for (final u in UnidadeInsumo.values)
                    DropdownMenuItem(value: u, child: Text(u.rotulo)),
                ],
                onChanged: (v) => setState(() => _unidade = v ?? _unidade),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _insumoOk ? _addInsumo : null,
              icon: const Icon(Icons.vaccines_outlined),
              label: const Text('Adicionar produto'),
            ),
          ],
        ),
        if (_erroInsumo != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_erroInsumo!, style: TextStyle(color: tema.colorScheme.error)),
          ),
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

        // ----- técnica, observações, justificativa -----
        const SizedBox(height: 16),
        TextField(
          controller: _tecnicaCtrl,
          decoration: const InputDecoration(
            labelText: 'Técnica geral (opcional)',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
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

/// Nova foto antes/depois: imagem, tipo e descrição em um painel só.
class _CompositorFoto extends StatefulWidget {
  final Future<String?> Function(String descricao, bool isAntes, ArquivoSelecionado arquivo)
      aoAdicionar;

  const _CompositorFoto({required this.aoAdicionar});

  @override
  State<_CompositorFoto> createState() => _CompositorFotoState();
}

class _CompositorFotoState extends State<_CompositorFoto> {
  final _descCtrl = TextEditingController();
  bool _antes = true;
  ArquivoSelecionado? _arquivo;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _descCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolher() async {
    final r = await escolherImagem();
    if (r == null) return;
    setState(() {
      _arquivo = r.arquivo ?? _arquivo;
      _erro = r.erro;
    });
  }

  bool get _ok => _arquivo != null && _descCtrl.text.trim().isNotEmpty;

  Future<void> _adicionar() async {
    final erro = await widget.aoAdicionar(_descCtrl.text.trim(), _antes, _arquivo!);
    if (erro == null && mounted) {
      setState(() {
        _descCtrl.clear();
        _arquivo = null;
        _erro = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final arquivo = _arquivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Adicionar foto', style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _escolher,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(arquivo?.nome ?? 'Escolher imagem'),
            ),
            if (arquivo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(arquivo.bytes, height: 56, fit: BoxFit.cover),
              ),
            ChoiceChip(
              label: const Text('Antes'),
              selected: _antes,
              onSelected: (_) => setState(() => _antes = true),
            ),
            ChoiceChip(
              label: const Text('Depois / acompanhamento'),
              selected: !_antes,
              onSelected: (_) => setState(() => _antes = false),
            ),
          ],
        ),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Descrição (ex.: Antes, 15 dias, Final) *',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _ok ? _adicionar : null,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Adicionar foto'),
        ),
      ],
    );
  }
}