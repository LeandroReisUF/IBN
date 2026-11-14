import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/lote_aplicado.dart';

double? _lerNumero(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

/// Produto, lote, validade e quantidade (RN06) inline. O lote só é entregue a
/// [aoAdicionar] depois de conferido: lote vencido é recusado aqui mesmo.
class PainelLoteAplicado extends StatefulWidget {
  final UnidadeInsumo unidadePadrao;
  final void Function(LoteAplicado lote) aoAdicionar;

  const PainelLoteAplicado({
    super.key,
    this.unidadePadrao = UnidadeInsumo.mililitros,
    required this.aoAdicionar,
  });

  @override
  State<PainelLoteAplicado> createState() => _PainelLoteAplicadoState();
}

class _PainelLoteAplicadoState extends State<PainelLoteAplicado> {
  final _produtoCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController();
  late UnidadeInsumo _unidade = widget.unidadePadrao;
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

  bool get _ok =>
      _produtoCtrl.text.trim().isNotEmpty &&
      _loteCtrl.text.trim().isNotEmpty &&
      _validade != null &&
      (_lerNumero(_qtdCtrl.text) ?? 0) > 0;

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
        _erro = null;
      });
    }
  }

  void _adicionar() {
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
    widget.aoAdicionar(lote);
    setState(() {
      _produtoCtrl.clear();
      _marcaCtrl.clear();
      _loteCtrl.clear();
      _qtdCtrl.clear();
      _validade = null;
      _erro = null;
    });
  }

  Widget _campo(TextEditingController c, String rotulo, double largura, {bool numero = false}) =>
      SizedBox(
        width: largura,
        child: TextField(
          controller: c,
          keyboardType: numero ? const TextInputType.numberWithOptions(decimal: true) : null,
          inputFormatters: numero ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _campo(_produtoCtrl, 'Produto *', 190),
            _campo(_marcaCtrl, 'Marca', 140),
            _campo(_loteCtrl, 'Lote *', 110),
            OutlinedButton.icon(
              onPressed: _escolherValidade,
              icon: const Icon(Icons.event_outlined),
              label: Text(_validade == null ? 'Validade *' : formatarData(_validade!)),
            ),
            _campo(_qtdCtrl, 'Qtd. usada *', 110, numero: true),
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
              onPressed: _ok ? _adicionar : null,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Adicionar produto'),
            ),
          ],
        ),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
          ),
      ],
    );
  }
}