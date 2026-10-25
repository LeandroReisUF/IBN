import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/especialidade.dart';
import '../../core/formadores.dart';
import '../../core/log_acesso.dart';
import '../../core/odontograma.dart';
import '../../core/odontograma_repository.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';
import '../../core/procedimento.dart';

/// Odontograma interativo (RF04.1): toque em uma face ou no número do dente.
class AbaOdontograma extends StatelessWidget {
  final Paciente paciente;
  const AbaOdontograma({super.key, required this.paciente});

  Future<void> _registrar(BuildContext context, int dente, FaceDente? face) async {
    final registro = await showDialog<RegistroDente>(
      context: context,
      builder: (_) => _DialogoRegistro(pacienteId: paciente.id, dente: dente, face: face),
    );
    if (registro == null) return;
    odontogramas.adicionar(registro);
    logsAcesso.registrar(
      usuarioId: registro.profissionalId,
      acao: 'registrou_odontograma',
      entidade: 'paciente',
      entidadeId: paciente.id,
    );
  }

  Widget _arcada(
    BuildContext context,
    List<int> dentes,
    bool superior,
    Map<String, RegistroDente> estado,
    bool podeEditar,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < dentes.length; i++) ...[
          if (i == 8) const SizedBox(width: 20), // linha média
          _DenteWidget(
            numero: dentes[i],
            superior: superior,
            estado: estado,
            podeEditar: podeEditar,
            aoToque: (dente, face) => _registrar(context, dente, face),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final podeEditar = politicaAcesso.podeEditarOdontograma(usuario, paciente);
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: odontogramas,
      builder: (context, _) {
        final estado = odontogramas.estadoAtual(paciente.id);
        final historico = odontogramas.historicoDoPaciente(paciente.id);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Legenda(),
            const SizedBox(height: 8),
            Text(
              podeEditar
                  ? 'Toque em uma face para registrar. Toque no número do dente para marcar o dente inteiro (existente/ausente).'
                  : 'Somente leitura.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      _arcada(context, dentesSuperiores, true, estado, podeEditar),
                      const SizedBox(height: 20),
                      _arcada(context, dentesInferiores, false, estado, podeEditar),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Histórico de registros', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (historico.isEmpty)
              const Text('Nenhum registro ainda.')
            else
              for (final r in historico) _linhaHistorico(r),
          ],
        );
      },
    );
  }

  Widget _linhaHistorico(RegistroDente r) {
    final prof = auth.buscarPorId(r.profissionalId);
    final proc = r.procedimentoId == null ? null : buscarProcedimento(r.procedimentoId!);
    final local = r.face == null
        ? 'Dente ${r.numeroDente}'
        : 'Dente ${r.numeroDente} • ${r.face!.rotulo}';
    final detalhes = [
      r.situacao.rotulo,
      if (proc != null) proc.nome,
      prof == null ? 'Profissional' : prof.nome,
      if (r.observacao.isNotEmpty) r.observacao,
    ].join('  •  ');
    return Card(
      child: ListTile(
        dense: true,
        title: Text('${formatarData(r.data)}  —  $local'),
        subtitle: Text(detalhes),
      ),
    );
  }
}

Color _corSituacao(SituacaoDente? s, ColorScheme cores) => switch (s) {
      null => cores.surface,
      SituacaoDente.existente => Colors.blueGrey.shade300,
      SituacaoDente.realizado => Colors.blue,
      SituacaoDente.planejado => Colors.red.shade400,
      SituacaoDente.ausente => Colors.grey.shade400,
    };

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    Widget item(SituacaoDente s) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _corSituacao(s, cores),
                border: Border.all(color: cores.outline, width: 0.8),
              ),
            ),
            const SizedBox(width: 6),
            Text(s.rotulo),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [for (final s in SituacaoDente.values) item(s)],
    );
  }
}

/// Desenha um dente com 5 faces em cruz e permite tocar em cada uma.
class _DenteWidget extends StatelessWidget {
  final int numero;
  final bool superior;
  final Map<String, RegistroDente> estado;
  final bool podeEditar;
  final void Function(int dente, FaceDente? face) aoToque;

  const _DenteWidget({
    required this.numero,
    required this.superior,
    required this.estado,
    required this.podeEditar,
    required this.aoToque,
  });

  static const double _tam = 38;
  static const double _borda = 11;
  static const double _centro = 16;

  // Vestibular sempre para fora da boca: no desenho, fica em cima nos dentes
  // superiores e embaixo nos inferiores.
  FaceDente get _faceTopo => superior ? FaceDente.vestibular : FaceDente.lingual;
  FaceDente get _faceBase => superior ? FaceDente.lingual : FaceDente.vestibular;

  // Mesial = lado voltado para a linha média. Quadrantes 1 e 4 ficam à
  // esquerda do desenho; 2 e 3, à direita.
  bool get _ladoEsquerdo {
    final q = numero ~/ 10;
    return q == 1 || q == 4;
  }

  FaceDente get _faceEsquerda => _ladoEsquerdo ? FaceDente.distal : FaceDente.mesial;
  FaceDente get _faceDireita => _ladoEsquerdo ? FaceDente.mesial : FaceDente.distal;

  Widget _face(
    BuildContext context,
    FaceDente face,
    double left,
    double top,
    double w,
    double h,
    bool ausente,
  ) {
    final cores = Theme.of(context).colorScheme;
    final reg = estado[RegistroDente.chave(numero, face)];
    final cor = ausente ? Colors.grey.shade300 : _corSituacao(reg?.situacao, cores);
    final situacao = reg == null ? '' : ': ${reg.situacao.rotulo}';
    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Tooltip(
        message: 'Dente $numero • ${face.rotulo}$situacao',
        child: InkWell(
          onTap: podeEditar && !ausente ? () => aoToque(numero, face) : null,
          child: Container(
            decoration: BoxDecoration(
              color: cor,
              border: Border.all(color: cores.outline, width: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final dente = estado[RegistroDente.chave(numero, null)];
    final ausente = dente?.situacao == SituacaoDente.ausente;

    final desenho = SizedBox(
      width: _tam,
      height: _tam,
      child: Stack(
        children: [
          _face(context, _faceTopo, _borda, 0, _centro, _borda, ausente),
          _face(context, _faceBase, _borda, _borda + _centro, _centro, _borda, ausente),
          _face(context, _faceEsquerda, 0, _borda, _borda, _centro, ausente),
          _face(context, _faceDireita, _borda + _centro, _borda, _borda, _centro, ausente),
          _face(context, FaceDente.oclusal, _borda, _borda, _centro, _centro, ausente),
          if (ausente)
            const Positioned.fill(
              child: IgnorePointer(child: Icon(Icons.close, color: Colors.black54)),
            ),
        ],
      ),
    );

    final rotulo = InkWell(
      onTap: podeEditar ? () => aoToque(numero, null) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$numero', style: tema.textTheme.labelMedium),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: superior ? [rotulo, desenho] : [desenho, rotulo],
      ),
    );
  }
}

class _DialogoRegistro extends StatefulWidget {
  final String pacienteId;
  final int dente;
  final FaceDente? face;

  const _DialogoRegistro({
    required this.pacienteId,
    required this.dente,
    required this.face,
  });

  @override
  State<_DialogoRegistro> createState() => _DialogoRegistroState();
}

class _DialogoRegistroState extends State<_DialogoRegistro> {
  SituacaoDente? _situacao;
  String? _procedimentoId;
  final _obsCtrl = TextEditingController();

  /// Face: existente/realizado/planejado. Dente inteiro: existente/ausente
  /// ("existente" serve para reverter um dente marcado como ausente).
  List<SituacaoDente> get _opcoes => widget.face == null
      ? const [SituacaoDente.existente, SituacaoDente.ausente]
      : const [SituacaoDente.existente, SituacaoDente.realizado, SituacaoDente.planejado];

  List<Procedimento> get _procedimentosOdonto =>
      procedimentos.where((p) => p.especialidade == Especialidade.odontologia).toList();

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    final situacao = _situacao;
    if (situacao == null) return;
    Navigator.of(context).pop(
      RegistroDente(
        id: odontogramas.novoId(),
        pacienteId: widget.pacienteId,
        numeroDente: widget.dente,
        face: widget.face,
        situacao: situacao,
        procedimentoId: widget.face == null ? null : _procedimentoId,
        observacao: _obsCtrl.text.trim(),
        data: DateTime.now(),
        profissionalId: auth.usuarioLogado!.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.face == null
        ? 'Dente ${widget.dente} (inteiro)'
        : 'Dente ${widget.dente} • ${widget.face!.rotulo}';

    return AlertDialog(
      title: Text(titulo),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _opcoes)
                    ChoiceChip(
                      label: Text(s.rotulo),
                      selected: _situacao == s,
                      onSelected: (_) => setState(() => _situacao = s),
                    ),
                ],
              ),
              if (widget.face != null) ...[
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
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
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
          onPressed: _situacao == null ? null : _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}