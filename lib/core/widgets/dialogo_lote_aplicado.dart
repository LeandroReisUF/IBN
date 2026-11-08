import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/lote_aplicado.dart';

double? _lerNumero(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

/// Diálogo de produto, lote, validade e quantidade (RN06). Devolve o
/// [LoteAplicado] já conferido (lote vencido é recusado no próprio diálogo).
/// Compartilhado por Biomedicina (e, depois, Estoque).
class DialogoLoteAplicado extends StatefulWidget {
  /// Unidade já escolhida ao abrir (HOF usa unidades; Biomedicina, mililitros).
  final UnidadeInsumo unidadePadrao;
  const DialogoLoteAplicado({super.key, this.unidadePadrao = UnidadeInsumo.mililitros});
  
  @override
  State<DialogoLoteAplicado> createState() => _DialogoLoteAplicadoState();
}

class _DialogoLoteAplicadoState extends State<DialogoLoteAplicado> {
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
                decoration: const InputDecoration(labelText: 'Produto *', border: OutlineInputBorder()),
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
                label: Text(_validade == null ? 'Validade *' : 'Validade: ${formatarData(_validade!)}'),
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