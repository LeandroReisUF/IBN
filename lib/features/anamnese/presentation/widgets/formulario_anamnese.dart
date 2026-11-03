import 'package:flutter/material.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';

/// Desenha um campo para cada pergunta do modelo (texto, sim/não, escolhas,
/// escala e data). Avisa a cada mudança com o mapa de respostas atual, já sem
/// as perguntas respondidas em branco.
class FormularioAnamnese extends StatefulWidget {
  final List<PerguntaAnamnese> perguntas;
  final Map<String, String> respostasIniciais;
  final void Function(Map<String, String> respostas) aoAlterar;

  const FormularioAnamnese({
    super.key,
    required this.perguntas,
    this.respostasIniciais = const {},
    required this.aoAlterar,
  });

  @override
  State<FormularioAnamnese> createState() => _FormularioAnamneseState();
}

class _FormularioAnamneseState extends State<FormularioAnamnese> {
  late final Map<String, String> _respostas;
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    _respostas = {
      for (final p in widget.perguntas)
        if ((widget.respostasIniciais[p.id] ?? '').trim().isNotEmpty)
          p.id: widget.respostasIniciais[p.id]!,
    };
    for (final p in widget.perguntas) {
      if (p.tipo == TipoResposta.texto || p.tipo == TipoResposta.textoLongo) {
        _ctrls[p.id] = TextEditingController(text: _respostas[p.id] ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _definir(String id, String? valor) {
    setState(() {
      final v = (valor ?? '').trim();
      if (v.isEmpty) {
        _respostas.remove(id);
      } else {
        _respostas[id] = v;
      }
    });
    widget.aoAlterar(Map.of(_respostas));
  }

  Future<void> _escolherData(PerguntaAnamnese p) async {
    final atual = DateTime.tryParse(_respostas[p.id] ?? '');
    final nova = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (nova == null) return;
    final m = nova.month.toString().padLeft(2, '0');
    final d = nova.day.toString().padLeft(2, '0');
    _definir(p.id, '${nova.year}-$m-$d');
  }

  Widget _titulo(PerguntaAnamnese p) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${p.enunciado}${p.obrigatoria ? ' *' : ''}', style: tema.textTheme.titleSmall),
        if (p.ajuda != null) Text(p.ajuda!, style: tema.textTheme.bodySmall),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _campo(PerguntaAnamnese p) {
    final valor = _respostas[p.id];
    switch (p.tipo) {
      case TipoResposta.texto || TipoResposta.textoLongo:
        return TextField(
          controller: _ctrls[p.id],
          maxLines: p.tipo == TipoResposta.textoLongo ? 4 : 1,
          minLines: 1,
          onChanged: (v) => _definir(p.id, v),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case TipoResposta.simNao:
        return SegmentedButton<String>(
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(value: 'sim', label: Text('Sim')),
            ButtonSegment(value: 'nao', label: Text('Não')),
          ],
          selected: valor == null ? <String>{} : {valor},
          onSelectionChanged: (s) => _definir(p.id, s.isEmpty ? null : s.first),
        );
      case TipoResposta.escolhaUnica:
        return DropdownButtonFormField<String>(
          key: ValueKey('escolha-${p.id}'),
          initialValue: p.opcoes.contains(valor) ? valor : null,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [for (final o in p.opcoes) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => _definir(p.id, v),
        );
      case TipoResposta.multiplaEscolha:
        final marcadas = separarMultipla(valor ?? '');
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final o in p.opcoes)
              FilterChip(
                label: Text(o),
                selected: marcadas.contains(o),
                onSelected: (sel) {
                  final novas = [...marcadas];
                  if (sel) {
                    novas.add(o);
                  } else {
                    novas.remove(o);
                  }
                  _definir(p.id, juntarMultipla(novas));
                },
              ),
          ],
        );
      case TipoResposta.escala:
        final n = int.tryParse(valor ?? '');
        return Row(
          children: [
            Expanded(
              child: Slider(
                value: (n ?? 0).toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '${n ?? 0}',
                onChanged: (v) => _definir(p.id, v.round().toString()),
              ),
            ),
            SizedBox(width: 80, child: Text(n == null ? 'sem resposta' : '$n/10')),
            if (n != null)
              IconButton(
                tooltip: 'Limpar',
                icon: const Icon(Icons.close),
                onPressed: () => _definir(p.id, null),
              ),
          ],
        );
      case TipoResposta.data:
        final d = DateTime.tryParse(valor ?? '');
        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _escolherData(p),
              icon: const Icon(Icons.event_outlined),
              label: Text(d == null ? 'Escolher data' : formatarData(d)),
            ),
            if (d != null)
              IconButton(
                tooltip: 'Limpar',
                icon: const Icon(Icons.close),
                onPressed: () => _definir(p.id, null),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in widget.perguntas) ...[
          _titulo(p),
          _campo(p),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}