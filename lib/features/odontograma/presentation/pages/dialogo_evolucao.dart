import 'package:flutter/material.dart';
import 'package:ibn/features/odontograma/domain/anatomia_dente.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/odontograma/domain/condicao_odonto.dart';
import 'package:ibn/core/especialidade.dart';
import 'package:ibn/features/odontograma/domain/odontograma.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/core/procedimento.dart';

/// Formulário completo "Adicionar evolução": condição, alvo, status,
/// procedimento e observação. Também serve para **retificar** um registro
/// ([retificando]): o registro errado fica riscado e este passa a valer.
class DialogoEvolucao extends StatefulWidget {
  final String pacienteId;
  final int dente;
  final FaceDente? face;
  final RaizDente? raiz;
  final RegistroDente? retificando;

  const DialogoEvolucao({
    super.key,
    required this.pacienteId,
    required this.dente,
    required this.face,
    this.raiz,
    this.retificando,
  });

  @override
  State<DialogoEvolucao> createState() => _DialogoEvolucaoState();
}

class _DialogoEvolucaoState extends State<DialogoEvolucao> {
  late AlvoOdonto _alvo;
  FaceDente? _face;
  RaizDente? _raiz;
  CondicaoOdonto? _condicao;
  StatusTratamento _status = StatusTratamento.existente;
  String? _procedimentoId;
  final _obsCtrl = TextEditingController();

  bool get _retificando => widget.retificando != null;

  List<RaizDente> get _raizesDoDente => AnatomiaDente.raizes(widget.dente);

  List<CondicaoOdonto> get _opcoes => CondicaoOdonto.paraAlvo(
        _alvo,
        deciduo: AnatomiaDente.ehDeciduo(widget.dente),
        multirradicular: _raizesDoDente.length > 1,
      );

  List<Procedimento> get _procedimentosOdonto =>
      procedimentos.where((p) => p.especialidade == Especialidade.odontologia).toList();

  @override
  void initState() {
    super.initState();
    final anterior = widget.retificando;
    if (anterior != null) {
      _alvo = anterior.alvo;
      _face = anterior.face;
      _raiz = anterior.raiz;
    } else {
      _alvo = widget.raiz != null
          ? AlvoOdonto.raiz
          : (widget.face != null ? AlvoOdonto.face : AlvoOdonto.dente);
      _face = widget.face;
      _raiz = widget.raiz;
    }
    _obsCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  bool get _podeSalvar {
    if (_condicao == null) return false;
    if (_retificando && _obsCtrl.text.trim().length < 3) return false;
    return true;
  }

  String _rotuloCondicao(CondicaoOdonto c) {
    if (c == CondicaoOdonto.nenhum) {
      return _retificando
          ? 'Anular o registro (sem nova marcação)'
          : 'Nenhum (limpar marcações)';
    }
    return '${c.rotulo} (${c.sigla})';
  }

  void _salvar() {
    final c = _condicao;
    if (c == null) return;
    Navigator.of(context).pop(
      RegistroDente(
        id: odontogramas.novoId(),
        pacienteId: widget.pacienteId,
        numeroDente: widget.dente,
        alvo: _alvo,
        face: _alvo == AlvoOdonto.face ? _face : null,
        raiz: _alvo == AlvoOdonto.raiz ? _raiz : null,
        condicao: c,
        status: c.usaStatus ? _status : StatusTratamento.existente,
        procedimentoId: c == CondicaoOdonto.nenhum ? null : _procedimentoId,
        observacao: _obsCtrl.text.trim(),
        data: DateTime.now(),
        profissionalId: auth.usuarioLogado!.id,
        retificaId: widget.retificando?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final condicao = _condicao;
    final titulo = _retificando
        ? 'Retificar registro • Dente ${widget.dente}'
        : 'Adicionar evolução • Dente ${widget.dente}';

    return AlertDialog(
      title: Text(titulo),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_retificando)
                Text(
                  'O registro anterior ficará riscado no histórico (nada é apagado). '
                  'Escolha a condição correta, ou anule o registro.',
                  style: tema.textTheme.bodySmall,
                )
              else
                SegmentedButton<AlvoOdonto>(
                  segments: const [
                    ButtonSegment(value: AlvoOdonto.dente, label: Text('Dente inteiro')),
                    ButtonSegment(value: AlvoOdonto.face, label: Text('Face')),
                    ButtonSegment(value: AlvoOdonto.raiz, label: Text('Raiz')),
                  ],
                  selected: {_alvo},
                  onSelectionChanged: (s) => setState(() {
                    _alvo = s.first;
                    if (_alvo == AlvoOdonto.face) _face ??= FaceDente.oclusal;
                    if (_alvo == AlvoOdonto.raiz) {
                      final raizes = _raizesDoDente;
                      if (_raiz == null || !raizes.contains(_raiz)) _raiz = raizes.first;
                    }
                    if (_condicao != null && !_condicao!.alvos.contains(_alvo)) {
                      _condicao = null;
                    }
                  }),
                ),
              if (_alvo == AlvoOdonto.face) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in FaceDente.values)
                      ChoiceChip(
                        label: Text(f.rotulo),
                        selected: _face == f,
                        onSelected: _retificando ? null : (_) => setState(() => _face = f),
                      ),
                  ],
                ),
              ],
              if (_alvo == AlvoOdonto.raiz) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in _raizesDoDente)
                      ChoiceChip(
                        label: Text(r.rotulo),
                        selected: _raiz == r,
                        onSelected: _retificando ? null : (_) => setState(() => _raiz = r),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<CondicaoOdonto>(
                key: ValueKey('condicao-${_alvo.name}-${widget.dente}'),
                initialValue: _condicao,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Condição',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in _opcoes)
                    DropdownMenuItem(value: c, child: Text(_rotuloCondicao(c))),
                ],
                onChanged: (v) => setState(() {
                  _condicao = v;
                  if (v != null && !v.usaStatus) _status = StatusTratamento.existente;
                }),
              ),
              if (condicao != null && condicao.usaStatus) ...[
                const SizedBox(height: 16),
                Text('Status do tratamento', style: tema.textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in StatusTratamento.values)
                      ChoiceChip(
                        label: Text(s.rotulo),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                  ],
                ),
              ],
              if (condicao != null && condicao != CondicaoOdonto.nenhum) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _procedimentoId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Procedimento (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in _procedimentosOdonto)
                      DropdownMenuItem(value: p.id, child: Text(p.nome)),
                  ],
                  onChanged: (v) => setState(() => _procedimentoId = v),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _retificando
                      ? 'Justificativa da retificação (obrigatória)'
                      : 'Evolução / observação (opcional)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _podeSalvar ? _salvar : null,
          child: Text(_retificando ? 'Retificar' : 'Salvar'),
        ),
      ],
    );
  }
}