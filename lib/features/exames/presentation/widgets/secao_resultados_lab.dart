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
/// visual de valores fora do padrão e o painel de lançamento inline.
/// Cria o próprio Cubit, escopado ao exame.
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

class _Secao extends StatefulWidget {
  final Exame exame;
  final bool podeEditar;
  const _Secao({required this.exame, required this.podeEditar});

  @override
  State<_Secao> createState() => _SecaoState();
}

class _SecaoState extends State<_Secao> {
  final _analitoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _unidadeCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  ResultadoExame? _corrigindo; // carregado no painel

  List<TextEditingController> get _todos =>
      [_analitoCtrl, _valorCtrl, _unidadeCtrl, _minCtrl, _maxCtrl, _justCtrl];

  @override
  void initState() {
    super.initState();
    for (final c in _todos) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _todos) {
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
      (_corrigindo == null || _justCtrl.text.trim().length >= 3);

  void _limpar() {
    setState(() {
      _corrigindo = null;
      for (final c in _todos) {
        c.clear();
      }
    });
  }

  void _carregarCorrecao(ResultadoExame r) {
    final d = r.dados;
    setState(() {
      _corrigindo = r;
      _analitoCtrl.text = d.analito;
      _valorCtrl.text = _num(d.valor);
      _unidadeCtrl.text = d.unidade;
      _minCtrl.text = d.refMin == null ? '' : _num(d.refMin!);
      _maxCtrl.text = d.refMax == null ? '' : _num(d.refMax!);
      _justCtrl.clear();
    });
  }

  Future<void> _lancar() async {
    final cubit = context.read<ResultadosLabCubit>();
    final mensagem = ScaffoldMessenger.of(context);
    final anterior = _corrigindo;
    final erro = await cubit.registrar(
      ResultadoLab(
        analito: _analitoCtrl.text.trim(),
        valor: _lerNumero(_valorCtrl.text)!,
        unidade: _unidadeCtrl.text.trim(),
        refMin: _min,
        refMax: _max,
      ),
      anterior: anterior,
      justificativa: anterior == null ? null : _justCtrl.text.trim(),
    );
    mensagem.showSnackBar(SnackBar(
      content: Text(erro ?? (anterior == null ? 'Resultado lançado.' : 'Resultado corrigido.')),
    ));
    if (erro == null && mounted) _limpar();
  }

  String _referencia(ResultadoLab d) {
    if (d.refMin == null && d.refMax == null) return 'sem referência';
    if (d.refMin != null && d.refMax != null) return 'ref. ${_num(d.refMin!)} a ${_num(d.refMax!)}';
    return d.refMin != null ? 'ref. mín. ${_num(d.refMin!)}' : 'ref. máx. ${_num(d.refMax!)}';
  }

  Widget _linha(ResultadoExame r, bool substituido) {
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
          if (!substituido && widget.podeEditar && widget.exame.status != StatusExame.cancelado)
            TextButton(onPressed: () => _carregarCorrecao(r), child: const Text('Corrigir')),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String rotulo, double largura, {bool numero = false}) =>
      SizedBox(
        width: largura,
        child: TextField(
          controller: c,
          keyboardType:
              numero ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
          inputFormatters: numero ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))] : null,
          decoration: InputDecoration(
            labelText: rotulo,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _painel() {
    final tema = Theme.of(context);
    final corrigindo = _corrigindo != null;
    final erro = _erro;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(corrigindo ? 'Corrigir resultado' : 'Lançar resultado',
              style: tema.textTheme.titleSmall),
          if (corrigindo)
            Text('O resultado anterior continua no histórico, riscado (RN05).',
                style: tema.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _campo(_analitoCtrl, 'Analito (ex.: Hemoglobina) *', 220),
              _campo(_valorCtrl, 'Valor *', 100, numero: true),
              _campo(_unidadeCtrl, 'Unidade *', 100),
              _campo(_minCtrl, 'Ref. mín.', 100, numero: true),
              _campo(_maxCtrl, 'Ref. máx.', 100, numero: true),
            ],
          ),
          if (erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(erro, style: TextStyle(color: tema.colorScheme.error)),
            ),
          if (corrigindo) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _justCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Justificativa da correção (obrigatória)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _ok ? _lancar : null,
                icon: Icon(corrigindo ? Icons.edit_outlined : Icons.add),
                label: Text(corrigindo ? 'Corrigir' : 'Lançar resultado'),
              ),
              if (corrigindo) TextButton(onPressed: _limpar, child: const Text('Cancelar')),
            ],
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
              for (final r in state.resultados) _linha(r, state.substituidos.contains(r.id)),
            if (widget.podeEditar && widget.exame.status != StatusExame.cancelado) _painel(),
          ],
        );
      },
    );
  }
}