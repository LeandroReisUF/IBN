import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/exames/data/resultados_lab_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/exames/domain/resultado_exame.dart';
import 'package:ibn/features/exames/presentation/cubit/resultados_lab_cubit.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

double? _lerNumero(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

/// Resultados laboratoriais estruturados de um exame (RF05.3), com sinalização
/// visual de valores fora do padrão. Cria o próprio Cubit, escopado ao exame.
class SecaoResultadosLab extends StatelessWidget {
  final Exame exame;
  final Paciente paciente;
  final bool podeEditar;

  const SecaoResultadosLab({
    super.key,
    required this.exame,
    required this.paciente,
    required this.podeEditar,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey('resultados-${exame.id}'),
      create: (_) => ResultadosLabCubit(
        repositorio: resultadosLabRepository,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
        exame: exame,
      )..carregar(),
      child: _Secao(exame: exame, podeEditar: podeEditar),
    );
  }
}

class _Secao extends StatelessWidget {
  final Exame exame;
  final bool podeEditar;
  const _Secao({required this.exame, required this.podeEditar});

  Future<void> _lancar(BuildContext context, {ResultadoExame? corrigindo}) async {
    final cubit = context.read<ResultadosLabCubit>();
    final mensagem = ScaffoldMessenger.of(context);
    final r = await showDialog<_DadosResultado>(
      context: context,
      builder: (_) => _DialogoResultado(base: corrigindo),
    );
    if (r == null) return;
    final erro = await cubit.registrar(r.dados, anterior: corrigindo, justificativa: r.justificativa);
    mensagem.showSnackBar(SnackBar(
      content: Text(erro ?? (corrigindo == null ? 'Resultado lançado.' : 'Resultado corrigido.')),
    ));
  }

  String _referencia(ResultadoLab d) {
    if (d.refMin == null && d.refMax == null) return 'sem referência';
    if (d.refMin != null && d.refMax != null) return 'ref. ${_num(d.refMin!)} a ${_num(d.refMax!)}';
    return d.refMin != null ? 'ref. mín. ${_num(d.refMin!)}' : 'ref. máx. ${_num(d.refMax!)}';
  }

  Widget _linha(BuildContext context, ResultadoExame r, bool substituido) {
    final tema = Theme.of(context);
    final d = r.dados;
    final alto = d.refMax != null && d.valor > d.refMax!;
    final alerta = !substituido && d.foraDoPadrao;
    final riscado = substituido ? const TextStyle(decoration: TextDecoration.lineThrough) : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: alerta ? tema.colorScheme.errorContainer : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (alerta)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(alto ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18, color: tema.colorScheme.error),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.analito}: ${_num(d.valor)} ${d.unidade}',
                    style: tema.textTheme.titleSmall?.merge(riscado)),
                Text(
                  '${_referencia(d)}'
                  '${r.retificaId == null ? '' : ' • corrige um anterior: ${r.justificativa ?? ''}'}',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (alerta)
            Text('FORA DO PADRÃO',
                style: tema.textTheme.labelSmall?.copyWith(
                  color: tema.colorScheme.error,
                  fontWeight: FontWeight.bold,
                )),
          if (substituido) const Chip(label: Text('Substituído')),
          if (!substituido && podeEditar && exame.status != StatusExame.cancelado)
            TextButton(
              onPressed: () => _lancar(context, corrigindo: r),
              child: const Text('Corrigir'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return BlocBuilder<ResultadosLabCubit, ResultadosLabState>(
      builder: (context, state) {
        if (state is! ResultadosLabSuccess) return const SizedBox.shrink();
        final alertas = state.alertas.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Row(
              children: [
                Expanded(child: Text('Resultados laboratoriais', style: tema.textTheme.titleSmall)),
                if (alertas > 0)
                  Chip(
                    avatar: Icon(Icons.warning_amber_rounded, size: 18, color: tema.colorScheme.error),
                    label: Text('$alertas fora do padrão'),
                    backgroundColor: tema.colorScheme.errorContainer,
                  ),
              ],
            ),
            if (state.resultados.isEmpty)
              Text('Nenhum resultado lançado.', style: tema.textTheme.bodySmall)
            else
              for (final r in state.resultados) _linha(context, r, state.substituidos.contains(r.id)),
            if (podeEditar && exame.status != StatusExame.cancelado)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _lancar(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Lançar resultado'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DadosResultado {
  final ResultadoLab dados;
  final String? justificativa;
  const _DadosResultado(this.dados, this.justificativa);
}

/// Resultado novo, ou correção quando [base] é informado (analito fixo).
class _DialogoResultado extends StatefulWidget {
  final ResultadoExame? base;
  const _DialogoResultado({this.base});

  @override
  State<_DialogoResultado> createState() => _DialogoResultadoState();
}

class _DialogoResultadoState extends State<_DialogoResultado> {
  final _analitoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _unidadeCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _justCtrl = TextEditingController();

  bool get _corrigindo => widget.base != null;

  @override
  void initState() {
    super.initState();
    final b = widget.base?.dados;
    if (b != null) {
      _analitoCtrl.text = b.analito;
      _valorCtrl.text = _num(b.valor);
      _unidadeCtrl.text = b.unidade;
      _minCtrl.text = b.refMin == null ? '' : _num(b.refMin!);
      _maxCtrl.text = b.refMax == null ? '' : _num(b.refMax!);
    }
    for (final c in [_analitoCtrl, _valorCtrl, _unidadeCtrl, _minCtrl, _maxCtrl, _justCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_analitoCtrl, _valorCtrl, _unidadeCtrl, _minCtrl, _maxCtrl, _justCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _min => _lerNumero(_minCtrl.text);
  double? get _max => _lerNumero(_maxCtrl.text);

  String? get _erro {
    if (_minCtrl.text.trim().isNotEmpty && _min == null) return 'Referência mínima inválida.';
    if (_maxCtrl.text.trim().isNotEmpty && _max == null) return 'Referência máxima inválida.';
    if (_min != null && _max != null && _min! > _max!) {
      return 'A referência mínima não pode passar da máxima.';
    }
    return null;
  }

  bool get _ok =>
      _analitoCtrl.text.trim().isNotEmpty &&
      _unidadeCtrl.text.trim().isNotEmpty &&
      _lerNumero(_valorCtrl.text) != null &&
      _erro == null &&
      (!_corrigindo || _justCtrl.text.trim().length >= 3);

  Widget _campoNumero(TextEditingController c, String rotulo) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
        decoration: InputDecoration(labelText: rotulo, border: const OutlineInputBorder()),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final erro = _erro;
    return AlertDialog(
      title: Text(_corrigindo ? 'Corrigir resultado' : 'Lançar resultado'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_corrigindo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'O resultado anterior continua no histórico, riscado (RN05).',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              TextField(
                controller: _analitoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Analito (ex.: Hemoglobina) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _campoNumero(_valorCtrl, 'Valor *')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unidadeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unidade *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _campoNumero(_minCtrl, 'Referência mín.')),
                  const SizedBox(width: 12),
                  Expanded(child: _campoNumero(_maxCtrl, 'Referência máx.')),
                ],
              ),
              if (erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(erro, style: TextStyle(color: tema.colorScheme.error)),
                ),
              if (_corrigindo) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _justCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Justificativa da correção (obrigatória)',
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
          onPressed: _ok
              ? () => Navigator.of(context).pop(_DadosResultado(
                    ResultadoLab(
                      analito: _analitoCtrl.text.trim(),
                      valor: _lerNumero(_valorCtrl.text)!,
                      unidade: _unidadeCtrl.text.trim(),
                      refMin: _min,
                      refMax: _max,
                    ),
                    _corrigindo ? _justCtrl.text.trim() : null,
                  ))
              : null,
          child: Text(_corrigindo ? 'Corrigir' : 'Lançar'),
        ),
      ],
    );
  }
}