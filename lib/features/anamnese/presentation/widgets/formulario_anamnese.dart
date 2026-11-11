import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';

/// Formulário inline: um campo para cada pergunta (texto, sim/não, chips,
/// escala e data). Quando as perguntas têm [PerguntaAnamnese.secao], cada
/// seção abre e minimiza. Perguntas condicionais só aparecem quando a resposta
/// pede, e perdem a resposta se voltarem a ficar ocultas. Avisa a cada mudança
/// com o mapa de respostas atual, sem as perguntas em branco.
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

  bool _vazia(String id) => (_respostas[id] ?? '').trim().isEmpty;

  void _definir(String id, String? valor) {
    setState(() {
      final v = (valor ?? '').trim();
      if (v.isEmpty) {
        _respostas.remove(id);
      } else {
        _respostas[id] = v;
      }
      // Pergunta condicional que ficou oculta perde a resposta.
      for (final p in widget.perguntas) {
        if (_respostas.containsKey(p.id) && !perguntaVisivel(p, _respostas)) {
          _respostas.remove(p.id);
          _ctrls[p.id]?.clear();
        }
      }
    });
    widget.aoAlterar(Map.of(_respostas));
  }

  void _semAlteracoes(List<PerguntaAnamnese> lista) {
    setState(() {
      for (final p in lista) {
        if (p.aceitaSemAlteracao && perguntaVisivel(p, _respostas) && _vazia(p.id)) {
          _respostas[p.id] = 'Sem alterações';
          _ctrls[p.id]?.text = 'Sem alterações';
        }
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
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        );
      case TipoResposta.simNao:
        return SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'sim', label: Text('Sim')),
            ButtonSegment(value: 'nao', label: Text('Não')),
          ],
          selected: valor == null ? <String>{} : {valor},
          onSelectionChanged: (s) => _definir(p.id, s.isEmpty ? null : s.first),
        );
      case TipoResposta.escolhaUnica:
        if (p.opcoes.length <= 4) {
          return Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final o in p.opcoes)
                ChoiceChip(
                  label: Text(o),
                  selected: valor == o,
                  onSelected: (sel) => _definir(p.id, sel ? o : null),
                ),
            ],
          );
        }
        return DropdownButtonFormField<String>(
          key: ValueKey('escolha-${p.id}'),
          initialValue: p.opcoes.contains(valor) ? valor : null,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
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
          mainAxisSize: MainAxisSize.min,
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

  /// Campos curtos ficam lado a lado; os longos ocupam a linha toda.
  bool _curta(PerguntaAnamnese p) => switch (p.tipo) {
        TipoResposta.texto || TipoResposta.simNao || TipoResposta.data => true,
        TipoResposta.escolhaUnica => p.opcoes.length <= 4,
        _ => false,
      };

  Widget _lista(List<PerguntaAnamnese> lista) {
    final visiveis = [for (final p in lista) if (perguntaVisivel(p, _respostas)) p];
    return LayoutBuilder(
      builder: (context, c) => Wrap(
        spacing: 16,
        runSpacing: 14,
        children: [
          for (final p in visiveis)
            SizedBox(
              width: _curta(p) ? math.min(300.0, c.maxWidth) : c.maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_titulo(p), _campo(p)],
              ),
            ),
        ],
      ),
    );
  }

  /// "Grupo|Seção" → (grupo, seção). Sem "|", só a seção.
  (String?, String?) _partes(String? secao) {
    if (secao == null) return (null, null);
    final i = secao.indexOf('|');
    return i < 0 ? (null, secao) : (secao.substring(0, i), secao.substring(i + 1));
  }

  List<PerguntaAnamnese> _visiveis(List<PerguntaAnamnese> lista) =>
      [for (final p in lista) if (perguntaVisivel(p, _respostas)) p];

  Widget _resumo(List<PerguntaAnamnese> lista) {
    final tema = Theme.of(context);
    final visiveis = _visiveis(lista);
    final respondidas = visiveis.where((p) => !_vazia(p.id)).length;
    final pendente = visiveis.any((p) => p.obrigatoria && _vazia(p.id));
    return Text(
      '$respondidas de ${visiveis.length}${pendente ? ' • obrigatória pendente' : ''}',
      style: tema.textTheme.bodySmall?.copyWith(
        color: pendente ? tema.colorScheme.error : null,
      ),
    );
  }

  Widget _secao(String titulo, List<PerguntaAnamnese> lista, bool aberta,
      {bool aninhada = false}) {
    final tema = Theme.of(context);
    final tile = ExpansionTile(
      key: ValueKey('sec-${lista.first.id}'),
      initiallyExpanded: aberta,
      maintainState: true,
      title: Text(titulo,
          style: aninhada ? tema.textTheme.titleSmall : tema.textTheme.titleMedium),
      subtitle: _resumo(lista),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_visiveis(lista).any((p) => p.aceitaSemAlteracao))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _semAlteracoes(lista),
              icon: const Icon(Icons.done_all),
              label: const Text('Preencher vazios com "Sem alterações"'),
            ),
          ),
        _lista(lista),
      ],
    );
    return aninhada ? tile : Card(margin: const EdgeInsets.only(bottom: 8), child: tile);
  }

  /// Bloco de nível 1 (ex.: "Exame físico") com as seções dentro.
  Widget _grupo(String titulo, Map<String?, List<PerguntaAnamnese>> secoes, bool aberto) {
    final tema = Theme.of(context);
    final todas = [for (final l in secoes.values) ...l];
    var i = 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: ValueKey('grupo-$titulo'),
        initiallyExpanded: aberto,
        maintainState: true,
        title: Text(titulo, style: tema.textTheme.titleMedium),
        subtitle: _resumo(todas),
        childrenPadding: const EdgeInsets.only(left: 8),
        children: [
          for (final e in secoes.entries)
            _secao(e.key ?? 'Outras', e.value, aberto && i++ == 0, aninhada: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = <String?, Map<String?, List<PerguntaAnamnese>>>{};
    for (final p in widget.perguntas) {
      final (g, s) = _partes(p.secao);
      grupos.putIfAbsent(g, () => {}).putIfAbsent(s, () => []).add(p);
    }
    if (grupos.length == 1 && grupos.containsKey(null) && grupos[null]!.containsKey(null)) {
      return _lista(widget.perguntas); // modelo sem seções: lista simples
    }
    var gi = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in grupos.entries)
          if (e.key == null)
            ...[for (final s in e.value.entries) _secao(s.key ?? 'Outras', s.value, false)]
          else
            _grupo(e.key!, e.value, gi++ == 0),
      ],
    );
  }
}