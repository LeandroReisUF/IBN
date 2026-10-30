import 'dart:typed_data';
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

/// Harmonização Orofacial (RF04.2, RN06). Esta classe só **fornece** o Cubit.
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
  bool get _podeEditar =>
      politicaAcesso.podeEditarHof(auth.usuarioLogado!, widget.paciente);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- ações ----------

  Future<void> _novo() async {
    final cubit = context.read<HofCubit>();
    if (!cubit.temAtendimentoAberto) {
      _aviso('Inicie um atendimento na aba Atendimentos antes de registrar o procedimento.');
      return;
    }
    final r = await showDialog<_DadosProcedimento>(
      context: context,
      builder: (_) => const _DialogoProcedimento(),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.registrar(
      tipo: r.tipo,
      tipoOutro: r.tipoOutro,
      pontos: r.pontos,
      insumos: r.insumos,
      tecnica: r.tecnica,
      observacoes: r.observacoes,
    );
    if (!mounted) return;
    _aviso(erro ?? 'Procedimento registrado.');
  }

  Future<void> _retificar(ProcedimentoHOF anterior) async {
    final cubit = context.read<HofCubit>();
    final r = await showDialog<_DadosProcedimento>(
      context: context,
      builder: (_) => _DialogoProcedimento(base: anterior),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.retificar(
      anterior,
      tipo: r.tipo,
      tipoOutro: r.tipoOutro,
      pontos: r.pontos,
      insumos: r.insumos,
      tecnica: r.tecnica,
      observacoes: r.observacoes,
      justificativa: r.justificativa ?? '',
    );
    if (!mounted) return;
    _aviso(erro ?? 'Registro retificado.');
  }

  Future<void> _anular(ProcedimentoHOF anterior) async {
    final cubit = context.read<HofCubit>();
    final just = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoJustificativa(),
    );
    if (just == null || !mounted) return;
    final erro = await cubit.anular(anterior, just);
    if (!mounted) return;
    _aviso(erro ?? 'Registro anulado.');
  }

  Future<void> _novaFoto() async {
    final cubit = context.read<HofCubit>();
    final r = await showDialog<_NovaFoto>(
      context: context,
      builder: (_) => const _DialogoFoto(),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.adicionarFoto(
      descricao: r.descricao,
      isAntes: r.isAntes,
      nomeArquivo: r.nome,
      bytes: r.bytes,
    );
    if (!mounted) return;
    _aviso(erro ?? 'Foto adicionada.');
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
                  TextButton(onPressed: () => _retificar(p), child: const Text('Retificar')),
                  TextButton(onPressed: () => _anular(p), child: const Text('Anular')),
                ],
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
    final antes = s.fotos.where((f) => f.isAntes).toList();
    final depois = s.fotos.where((f) => !f.isAntes).toList();

    return ListView(
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _novo,
                        icon: const Icon(Icons.add),
                        label: const Text('Novo procedimento'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _novaFoto,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Adicionar foto'),
                      ),
                    ],
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

// ---------- diálogos ----------

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

/// Procedimento novo, ou retificação quando [base] é informado.
class _DialogoProcedimento extends StatefulWidget {
  final ProcedimentoHOF? base;
  const _DialogoProcedimento({this.base});

  @override
  State<_DialogoProcedimento> createState() => _DialogoProcedimentoState();
}

class _DialogoProcedimentoState extends State<_DialogoProcedimento> {
  late TipoHOF _tipo;
  final _outroCtrl = TextEditingController();
  final _tecnicaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  final List<PontoAplicacao> _pontos = [];
  final List<LoteAplicado> _insumos = [];

  bool get _retificando => widget.base != null;

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
    for (final c in [_outroCtrl, _justCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _outroCtrl.dispose();
    _tecnicaCtrl.dispose();
    _obsCtrl.dispose();
    _justCtrl.dispose();
    super.dispose();
  }

  bool get _podeSalvar =>
      _pontos.isNotEmpty &&
      (_tipo != TipoHOF.outro || _outroCtrl.text.trim().isNotEmpty) &&
      (!_tipo.exigeLote || _insumos.isNotEmpty) &&
      (!_retificando || _justCtrl.text.trim().length >= 3);

  Future<void> _addPonto() async {
    final p = await showDialog<PontoAplicacao>(
      context: context,
      builder: (_) => const _DialogoPonto(),
    );
    if (p != null) setState(() => _pontos.add(p));
  }

  Future<void> _addInsumo() async {
    final i = await showDialog<LoteAplicado>(
      context: context,
      builder: (_) => const _DialogoInsumo(),
    );
    if (i != null) setState(() => _insumos.add(i));
  }

  void _salvar() {
    String? limpo(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    Navigator.of(context).pop(_DadosProcedimento(
      tipo: _tipo,
      tipoOutro: _tipo == TipoHOF.outro ? limpo(_outroCtrl) : null,
      pontos: List.of(_pontos),
      insumos: List.of(_insumos),
      tecnica: limpo(_tecnicaCtrl),
      observacoes: _obsCtrl.text.trim(),
      justificativa: _retificando ? _justCtrl.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(_retificando ? 'Retificar procedimento' : 'Novo procedimento de HOF'),
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
              DropdownButtonFormField<TipoHOF>(
                initialValue: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de procedimento *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final t in TipoHOF.values) DropdownMenuItem(value: t, child: Text(t.rotulo)),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              if (_tipo == TipoHOF.outro) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _outroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descreva o procedimento *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Pontos de aplicação *', style: tema.textTheme.titleSmall),
              for (var i = 0; i < _pontos.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_pontos[i].area.rotulo} (${_pontos[i].lado.rotulo}) • ${_num(_pontos[i].quantidade)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remover ponto (ainda não registrado)',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _pontos.removeAt(i)),
                  ),
                ),
              TextButton.icon(
                onPressed: _addPonto,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Adicionar ponto'),
              ),
              const SizedBox(height: 8),
              Text(
                _tipo.exigeLote ? 'Produto, lote e validade * (RN06)' : 'Produto, lote e validade',
                style: tema.textTheme.titleSmall,
              ),
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
                    tooltip: 'Remover insumo (ainda não registrado)',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _insumos.removeAt(i)),
                  ),
                ),
              TextButton.icon(
                onPressed: _addInsumo,
                icon: const Icon(Icons.vaccines_outlined),
                label: const Text('Adicionar produto / lote'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tecnicaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Técnica geral (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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

class _DialogoPonto extends StatefulWidget {
  const _DialogoPonto();

  @override
  State<_DialogoPonto> createState() => _DialogoPontoState();
}

class _DialogoPontoState extends State<_DialogoPonto> {
  AreaFace _area = AreaFace.testa;
  LadoFace _lado = LadoFace.bilateral;
  final _qtdCtrl = TextEditingController();
  final _profCtrl = TextEditingController();
  final _tecCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qtdCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _profCtrl.dispose();
    _tecCtrl.dispose();
    super.dispose();
  }

  double? get _qtd => _lerNumero(_qtdCtrl.text);
  bool get _ok => (_qtd ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ponto de aplicação'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AreaFace>(
                initialValue: _area,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Região', border: OutlineInputBorder()),
                items: [
                  for (final a in AreaFace.values)
                    DropdownMenuItem(value: a, child: Text(a.rotulo)),
                ],
                onChanged: (v) => setState(() => _area = v ?? _area),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LadoFace>(
                initialValue: _lado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lado', border: OutlineInputBorder()),
                items: [
                  for (final l in LadoFace.values)
                    DropdownMenuItem(value: l, child: Text(l.rotulo)),
                ],
                onChanged: (v) => setState(() => _lado = v ?? _lado),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtdCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(
                  labelText: 'Quantidade (U ou ml) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _profCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(
                  labelText: 'Profundidade em mm (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tecCtrl,
                decoration: const InputDecoration(
                  labelText: 'Técnica (opcional)',
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
              ? () {
                  final tec = _tecCtrl.text.trim();
                  Navigator.of(context).pop(PontoAplicacao(
                    area: _area,
                    lado: _lado,
                    quantidade: _qtd!,
                    profundidadeMm: _lerNumero(_profCtrl.text),
                    tecnica: tec.isEmpty ? null : tec,
                  ));
                }
              : null,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _DialogoInsumo extends StatefulWidget {
  const _DialogoInsumo();

  @override
  State<_DialogoInsumo> createState() => _DialogoInsumoState();
}

class _DialogoInsumoState extends State<_DialogoInsumo> {
  final _produtoCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController();
  UnidadeInsumo _unidade = UnidadeInsumo.unidades;
  DateTime? _validade;
  String? _erro;

  @override
  void initState() {
    super.initState();
    for (final c in [_produtoCtrl, _loteCtrl, _qtdCtrl]) {
      c.addListener(() => setState(() => _erro = null));
    }
  }

  @override
  void dispose() {
    _produtoCtrl.dispose();
    _marcaCtrl.dispose();
    _loteCtrl.dispose();
    _qtdCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherValidade() async {
    final agora = DateTime.now();
    final nova = await showDatePicker(
      context: context,
      initialDate: _validade ?? soData(agora),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (nova != null) {
      setState(() {
        _validade = soData(nova);
        _erro = null;
      });
    }
  }

  bool get _ok =>
      _produtoCtrl.text.trim().isNotEmpty &&
      _loteCtrl.text.trim().isNotEmpty &&
      _validade != null &&
      (_lerNumero(_qtdCtrl.text) ?? 0) > 0;

  void _confirmar() {
    final marca = _marcaCtrl.text.trim();
    final lote = LoteAplicado(
      produto: _produtoCtrl.text.trim(),
      marca: marca.isEmpty ? null : marca,
      lote: _loteCtrl.text.trim(),
      validade: _validade!,
      quantidade: _lerNumero(_qtdCtrl.text)!,
      unidade: _unidade,
    );
    final erro = lote.validar(DateTime.now());
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    Navigator.of(context).pop(lote);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: const Text('Produto e lote (RN06)'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _produtoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Produto *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _marcaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marca / fabricante (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _loteCtrl,
                decoration: const InputDecoration(labelText: 'Lote *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _escolherValidade,
                icon: const Icon(Icons.event_outlined),
                label: Text(_validade == null
                    ? 'Validade *'
                    : 'Validade: ${formatarData(_validade!)}'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtdCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Quantidade usada *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<UnidadeInsumo>(
                      initialValue: _unidade,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        for (final u in UnidadeInsumo.values)
                          DropdownMenuItem(value: u, child: Text(u.rotulo)),
                      ],
                      onChanged: (v) => setState(() => _unidade = v ?? _unidade),
                    ),
                  ),
                ],
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _ok ? _confirmar : null, child: const Text('Adicionar')),
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
          onPressed: _ctrl.text.trim().length >= 3
              ? () => Navigator.of(context).pop(_ctrl.text.trim())
              : null,
          child: const Text('Anular'),
        ),
      ],
    );
  }
}

class _NovaFoto {
  final String descricao;
  final bool isAntes;
  final String nome;
  final Uint8List bytes;
  const _NovaFoto(this.descricao, this.isAntes, this.nome, this.bytes);
}

class _DialogoFoto extends StatefulWidget {
  const _DialogoFoto();

  @override
  State<_DialogoFoto> createState() => _DialogoFotoState();
}

class _DialogoFotoState extends State<_DialogoFoto> {
  final _descCtrl = TextEditingController();
  bool _antes = false;
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

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final arquivo = _arquivo;
    return AlertDialog(
      title: const Text('Adicionar foto'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _escolher,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(arquivo?.nome ?? 'Escolher imagem'),
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
                ),
              if (arquivo != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(arquivo.bytes, height: 140, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrição (ex.: Antes, 15 dias, Final) *',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Foto "ANTES"'),
                value: _antes,
                onChanged: (v) => setState(() => _antes = v ?? false),
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
                    _NovaFoto(_descCtrl.text.trim(), _antes, arquivo!.nome, arquivo.bytes),
                  )
              : null,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}