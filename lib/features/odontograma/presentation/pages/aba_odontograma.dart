import 'package:flutter/material.dart';
import 'package:ibn/features/odontograma/domain/anatomia_dente.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/odontograma/domain/condicao_odonto.dart';
import 'package:ibn/features/odontograma/data/desenhos_dentes.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/odontograma/domain/odontograma.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/odontograma/presentation/widgets/caixa_dente.dart';
import 'package:ibn/features/odontograma/presentation/widgets/desenho_dente.dart';
import 'package:ibn/features/odontograma/presentation/pages/dialogo_evolucao.dart';
import 'package:ibn/features/odontograma/presentation/pages/menu_condicoes.dart';

/// Tamanho dos dentes decíduos em relação aos permanentes.
const double _fatorDeciduo = 0.75;

/// Idade abaixo da qual a faixa de decíduos já vem marcada (dentição mista).
const int _idadeDeciduosAutomatico = 13;

/// Qual odontograma: o clínico geral ou o da ortodontia (aba Ortodontia).
enum ModoOdontograma { geral, ortodontia }


/// Odontograma interativo (RF04.1): desenho, número e caixa dividida de cada dente.
class AbaOdontograma extends StatefulWidget {
  final Paciente paciente;

  /// Quando informada, os registros são lidos e gravados sob esta chave no lugar
  /// do id do paciente (usado pelo odontograma desejado de um plano).
  final String? chaveRegistros;

  /// Aviso mostrado no topo (opcional).
  final String? aviso;

  final ModoOdontograma modo;

/// true = dentro de outra lista rolável (não rola sozinho).
final bool embutido;

  const AbaOdontograma({
    super.key,
    required this.paciente,
    this.chaveRegistros,
    this.aviso,
    this.modo = ModoOdontograma.geral,
    this.embutido = false,
  });
  @override
  State<AbaOdontograma> createState() => _AbaOdontogramaState();
}

class _AbaOdontogramaState extends State<AbaOdontograma> {
  VisaoOdontograma _visao = VisaoOdontograma.atual;
  DateTime _dataVisao = soData(DateTime.now());
  final Set<CategoriaCondicao> _ocultas = {};
  bool _legendaCompleta = false;
  late bool _mostrarDeciduos;

  // Marcas de arcada ortodôntica (Fase E)
  Map<ArcadaOdonto, List<TipoMarcaArcada>> _marcasArcadaAtivas = {
    ArcadaOdonto.superior: [],
    ArcadaOdonto.inferior: [],
  };

  static const _categoriasFiltraveis = [
    CategoriaCondicao.estado,
    CategoriaCondicao.patologia,
    CategoriaCondicao.restauracao,
    CategoriaCondicao.protese,
    CategoriaCondicao.indicacao,
    CategoriaCondicao.periodonto,
    CategoriaCondicao.raiz,
  ];
    bool get _orto => widget.modo == ModoOdontograma.ortodontia;

  /// O odontograma geral não mostra ortodontia; o da ortodontia mostra só ela.
  bool _doModo(RegistroDente r) =>
      (r.condicao.categoria == CategoriaCondicao.ortodontia) == _orto;

  bool _doModoHistorico(RegistroDente r, Map<String, RegistroDente> porId) {
    if (r.condicao == CondicaoOdonto.nenhum) {
      // Anular um registro ortodôntico fica na ortodontia; o resto, no geral.
      final alvo = r.retificaId == null ? null : porId[r.retificaId!];
      final ehOrto = alvo != null && alvo.condicao.categoria == CategoriaCondicao.ortodontia;
      return ehOrto == _orto;
    }
    return _doModo(r);
  }

  /// Com [chaveRegistros], todo `_paciente.id` do arquivo vira essa chave; as
  /// permissões (vínculos) continuam as do paciente real.
  Paciente get _paciente {
    final chave = widget.chaveRegistros;
    if (chave == null) return widget.paciente;
    final p = widget.paciente;
    return Paciente(
      id: chave,
      nome: p.nome,
      cpf: p.cpf,
      dataNascimento: p.dataNascimento,
      telefone: p.telefone,
      termoLgpd: p.termoLgpd,
      profissionaisVinculados: p.profissionaisVinculados,
    );
  }
  @override
  void initState() {
    super.initState();
    // Dentição mista: abaixo de 13 anos a faixa de decíduos já vem marcada.
    _mostrarDeciduos = idadeEm(widget.paciente.dataNascimento) < _idadeDeciduosAutomatico;
    // Carrega marcas de arcada ortodôntica ativas.
    _carregarMarcasArcada();
  }

  void _carregarMarcasArcada() {
    final ativas = odontogramas.marcasArcadaAtivas(_paciente.id);
    setState(() => _marcasArcadaAtivas = ativas);
  }

    void _alternarMarcaArcada(ArcadaOdonto arcada, TipoMarcaArcada tipo) {
    final usuarioId = auth.usuarioLogado!.id;
    final existente = odontogramas.marcaAtiva(_paciente.id, arcada, tipo);

    // Desmarcar = novo registro que retifica o ativo (nada é apagado, RN05).
    odontogramas.adicionarMarcaArcada(MarcaArcada(
      id: odontogramas.novoId(),
      pacienteId: _paciente.id,
      arcada: arcada,
      tipo: tipo,
      status: StatusTratamento.existente,
      data: DateTime.now(),
      profissionalId: usuarioId,
      retificaId: existente?.id,
    ));
    logsAcesso.registrar(
      usuarioId: usuarioId,
      acao: existente == null ? 'marcou_arcada_orto' : 'desmarcou_arcada_orto',
      entidade: 'paciente',
      entidadeId: widget.paciente.id,
          );
    _carregarMarcasArcada();
  }

  // ---------- ações ----------

  Future<void> _abrirMenu(
    int dente,
    FaceDente? face,
    RaizDente? raiz,
    List<RegistroDente> marcacoes,
  ) async {
    final largo = MediaQuery.sizeOf(context).width >= 600;
    final menu = MenuCondicoes(dente: dente, face: face, raiz: raiz, marcacoes: marcacoes, ortodontia: _orto,);
    final resultado = largo
        ? await showDialog<ResultadoMenu>(
            context: context,
            builder: (_) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: menu,
              ),
            ),
          )
        : await showModalBottomSheet<ResultadoMenu>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SafeArea(child: menu),
          );
    if (resultado == null || !mounted) return;

    if (resultado.condicao != null) {
      // Registro rápido: a condição escolhida, como "Existente".
      _gravar(RegistroDente(
        id: odontogramas.novoId(),
        pacienteId: _paciente.id,
        numeroDente: dente,
        alvo: raiz != null
            ? AlvoOdonto.raiz
            : (face != null ? AlvoOdonto.face : AlvoOdonto.dente),
        face: face,
        raiz: raiz,
        condicao: resultado.condicao!,
        data: DateTime.now(),
        profissionalId: auth.usuarioLogado!.id,
      ));
    } else {
      final registro = await showDialog<RegistroDente>(
        context: context,
        builder: (_) => DialogoEvolucao(
          pacienteId: _paciente.id,
          dente: dente,
          face: face,
          raiz: raiz,
          ortodontia: _orto,
        ),
      );
      if (registro != null && mounted) _gravar(registro);
    }
  }

  Future<void> _retificar(RegistroDente anterior) async {
    final registro = await showDialog<RegistroDente>(
      context: context,
      builder: (_) => DialogoEvolucao(
        pacienteId: _paciente.id,
        dente: anterior.numeroDente,
        face: anterior.face,
        raiz: anterior.raiz,
        retificando: anterior,
        ortodontia: _orto,
      ),
    );
    if (registro != null && mounted) _gravar(registro);
  }

  void _gravar(RegistroDente registro) {
    final erro = odontogramas.adicionar(registro);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    // RNF03: todo registro no prontuário gera um registro de acesso.
    logsAcesso.registrar(
      usuarioId: registro.profissionalId,
      acao: registro.retificaId == null ? 'registrou_odontograma' : 'retificou_odontograma',
      entidade: 'paciente',
      entidadeId: widget.paciente.id,
          );
  }

  Future<void> _escolherData() async {
    final nova = await showDatePicker(
      context: context,
      initialDate: _dataVisao,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nova != null) setState(() => _dataVisao = soData(nova));
  }

  // ---------- visual ----------

  Map<int, List<RegistroDente>> _agrupar(Iterable<RegistroDente> registros) {
    final mapa = <int, List<RegistroDente>>{};
    for (final r in registros) {
      mapa.putIfAbsent(r.numeroDente, () => []).add(r);
    }
    return mapa;
  }

  /// Uma fileira de dentes. [lacunaApos] deixa o espaço da linha média.
  Widget _fileira(
    List<int> dentes,
    bool superior,
    Map<int, List<RegistroDente>> visiveis,
    Map<int, List<RegistroDente>> todas,
    bool editavel, {
    required int lacunaApos,
    double lacuna = 20,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < dentes.length; i++) ...[
          if (i == lacunaApos) SizedBox(width: lacuna), // linha média
          _DenteWidget(
            numero: dentes[i],
            somenteCoroa: _orto,
            superior: superior,
            marcacoes: visiveis[dentes[i]] ?? const [],
            editavel: editavel,
            aoToque: (dente, face, raiz) =>
                _abrirMenu(dente, face, raiz, todas[dente] ?? const []),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final podeEditar = _orto
        ? politicaAcesso.podeEditarOrtodontia(usuario, _paciente)
        : politicaAcesso.podeEditarOdontograma(usuario, _paciente);    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: odontogramas,
      builder: (context, _) {
        final ate = _visao == VisaoOdontograma.emData
            ? DateTime(_dataVisao.year, _dataVisao.month, _dataVisao.day, 23, 59, 59)
            : null;
        final estadoCompleto = odontogramas.estadoAtual(_paciente.id, visao: _visao, ate: ate);
                final doModo = estadoCompleto.values.where(_doModo).toList();
        final visiveis =
            doModo.where((r) => !_ocultas.contains(r.condicao.categoria)).toList();
        final todosHistorico = odontogramas.historicoDoPaciente(_paciente.id);
        final porId = {for (final r in todosHistorico) r.id: r};
        final historico =
            todosHistorico.where((r) => _doModoHistorico(r, porId)).toList();
        final retificados = odontogramas.retificados(_paciente.id);
        final editavel = podeEditar && _visao == VisaoOdontograma.atual;
        final porDenteVisivel = _agrupar(visiveis);
        final porDenteCompleto = _agrupar(doModo);
        final temDeciduos = doModo.any((r) => AnatomiaDente.ehDeciduo(r.numeroDente));
        
        return FutureBuilder<void>(
          future: desenhosDentes.carregar(),
          builder: (context, carregamento) => ListView(
            shrinkWrap: widget.embutido,
            physics: widget.embutido ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.all(16),
            children: [
                            if (widget.aviso != null)
                Card(
                  color: tema.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(widget.aviso!),
                  ),
                ),
              if (carregamento.hasError)
                Card(
                  color: tema.colorScheme.errorContainer,
                  child: const ListTile(
                    leading: Icon(Icons.image_not_supported_outlined),
                    title: Text('Desenhos dos dentes não encontrados.'),
                    subtitle: Text(
                      'Rode "dart run tool/gerar_dentes_json.dart" e confira o pubspec.yaml. '
                      'O odontograma continua funcionando só com as caixas.',
                    ),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Odontograma:', style: tema.textTheme.labelLarge),
                  SegmentedButton<VisaoOdontograma>(
                    segments: [
                      for (final v in VisaoOdontograma.values)
                        ButtonSegment(value: v, label: Text(v.rotulo)),
                    ],
                    selected: {_visao},
                    onSelectionChanged: (s) => setState(() => _visao = s.first),
                  ),
                  if (_visao == VisaoOdontograma.emData)
                    OutlinedButton.icon(
                      onPressed: _escolherData,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(formatarData(_dataVisao)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () => setState(() => _mostrarDeciduos = !_mostrarDeciduos),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _mostrarDeciduos,
                          onChanged: (v) => setState(() => _mostrarDeciduos = v ?? false),
                        ),
                        const Text('Mostrar dentes decíduos'),
                      ],
                    ),
                  ),
                  if (temDeciduos && !_mostrarDeciduos)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.child_care, size: 16),
                      label: Text('Há registros em dentes decíduos'),
                    ),
                ],
              ),
              // ---- Marcas de arcada ortodôntica (Fase E) ----
              if (_orto) ...[
                const SizedBox(height: 8),
                _MarcasArcadaOrto(
                  marcasAtivas: _marcasArcadaAtivas,
                  aoAlterar: editavel ? _alternarMarcaArcada : null,
                ),
              ],
              if (!_orto) Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in _categoriasFiltraveis)
                    FilterChip(
                      label: Text(c.rotulo),
                      selected: !_ocultas.contains(c),
                      onSelected: (marcado) => setState(() {
                        if (marcado) {
                          _ocultas.remove(c);
                        } else {
                          _ocultas.add(c);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                editavel
                    ? (_orto
                        ? 'Toque na coroa ou no número do dente para marcar braquete, banda, tubo e outros acessórios.'
                        : 'Toque em um setor da caixa para marcar uma face, na raiz do desenho para marcar uma raiz, '
                            'ou na coroa/número para marcar o dente inteiro.')
                    : (podeEditar
                        ? 'Visão de consulta: volte para "Atual" para registrar.'
                        : 'Somente leitura.'),
                style: tema.textTheme.bodySmall,
              ),              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      children: [
                        _fileira(dentesSuperiores, true, porDenteVisivel, porDenteCompleto,
                            editavel, lacunaApos: 8),
                        if (_mostrarDeciduos) ...[
                          const SizedBox(height: 12),
                          _fileira(deciduosSuperiores, true, porDenteVisivel, porDenteCompleto,
                              editavel, lacunaApos: 5, lacuna: 16),
                          const SizedBox(height: 8),
                          _fileira(deciduosInferiores, false, porDenteVisivel, porDenteCompleto,
                              editavel, lacunaApos: 5, lacuna: 16),
                          const SizedBox(height: 12),
                        ] else
                          const SizedBox(height: 20),
                        _fileira(dentesInferiores, false, porDenteVisivel, porDenteCompleto,
                            editavel, lacunaApos: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Legenda(
                emUso: {for (final r in visiveis) r.condicao},
                completa: _legendaCompleta,
                aoAlternar: () => setState(() => _legendaCompleta = !_legendaCompleta),
                ortodontia: _orto,
              ),
              const SizedBox(height: 24),
              Text('Histórico de registros', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (historico.isEmpty)
                const Text('Nenhum registro ainda.')
              else
                for (final r in historico) _linhaHistorico(r, retificados, editavel),
            ],
          ),
        );
      },
    );
  }

  Widget _linhaHistorico(RegistroDente r, Set<String> retificados, bool editavel) {
    final prof = auth.buscarPorId(r.profissionalId);
    final proc = r.procedimentoId == null ? null : buscarProcedimento(r.procedimentoId!);
    final foiRetificado = retificados.contains(r.id);
    final String local;
    if (r.raiz != null) {
      local = 'Dente ${r.numeroDente} • ${r.raiz!.rotulo}';
    } else if (r.face != null) {
      local = 'Dente ${r.numeroDente} • ${r.face!.rotulo}';
    } else {
      local = 'Dente ${r.numeroDente}';
    }

    final String oQue;
    if (r.ehAnulacao) {
      oQue = 'Anulou um registro anterior';
    } else if (r.condicao == CondicaoOdonto.nenhum) {
      oQue = 'Limpou as marcações';
    } else {
      oQue = '${r.condicao.rotulo} (${r.condicao.sigla})';
    }
    final detalhes = [
      if (r.retificaId != null && !r.ehAnulacao) 'Retifica um registro anterior',
      oQue,
      if (r.condicao.usaStatus && !r.ehAnulacao) r.status.rotulo,
      if (proc != null) proc.nome,
      prof == null ? 'Profissional' : prof.nome,
      if (r.observacao.isNotEmpty) r.observacao,
    ].join('  •  ');

    final riscado = foiRetificado
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    return Card(
      child: ListTile(
        dense: true,
        title: Text('${formatarData(r.data)}  —  $local', style: riscado),
        subtitle: Text(detalhes, style: riscado),
        trailing: foiRetificado
            ? const Chip(label: Text('Retificado'))
            : (editavel && !r.ehAnulacao
                ? TextButton(onPressed: () => _retificar(r), child: const Text('Retificar'))
                : null),
      ),
    );
  }
}

/// Legenda: só as condições em uso (com opção de ver todas) e o estilo do status.
class _Legenda extends StatelessWidget {
  final Set<CondicaoOdonto> emUso;
  final bool completa;
  final VoidCallback aoAlternar;
  final bool ortodontia;

  const _Legenda({required this.emUso, required this.completa, required this.aoAlternar, required this.ortodontia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lista = (completa
            ? CondicaoOdonto.values
                .where((c) =>
                    c != CondicaoOdonto.nenhum &&
                    (c.categoria == CategoriaCondicao.ortodontia) == ortodontia)
                .toSet()
            : emUso)
        .toList()
      ..sort((a, b) => a.prioridade.compareTo(b.prioridade));

    Widget item(CondicaoOdonto c) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(c.corArgb),
                border: Border.all(color: tema.colorScheme.outline, width: 0.8),
              ),
            ),
            const SizedBox(width: 6),
            Text('${c.sigla} — ${c.rotulo}', style: tema.textTheme.bodySmall),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Legenda', style: tema.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (lista.isEmpty)
          Text('Nenhuma marcação neste odontograma.', style: tema.textTheme.bodySmall)
        else
          Wrap(spacing: 16, runSpacing: 6, children: [for (final c in lista) item(c)]),
        const SizedBox(height: 6),
        Text(
          'Cheio = existente/realizado · Tracejado e claro = planejado · Meio claro = em andamento',
          style: tema.textTheme.bodySmall,
        ),
        TextButton(
          onPressed: aoAlternar,
          child: Text(completa ? 'Mostrar só as em uso' : 'Ver todas as condições'),
        ),
      ],
    );
  }
}

/// Um dente: desenho 2D + número + caixa dividida (5 faces).
/// Superiores: desenho, número, caixa. Inferiores: caixa, número, desenho.
class _DenteWidget extends StatelessWidget {
  final int numero;
  final bool superior;
  final List<RegistroDente> marcacoes; // marcações visíveis deste dente
  final bool editavel;
  final void Function(int dente, FaceDente? face, RaizDente? raiz) aoToque;
  final bool somenteCoroa;

  const _DenteWidget({
    required this.numero,
    required this.superior,
    required this.marcacoes,
    required this.editavel,
    required this.aoToque,
    required this.somenteCoroa,
  });

  // Vestibular sempre para fora da boca: no desenho, fica em cima nos dentes
  // superiores e embaixo nos inferiores.
  FaceDente get _faceTopo => superior ? FaceDente.vestibular : FaceDente.lingual;
  FaceDente get _faceBase => superior ? FaceDente.lingual : FaceDente.vestibular;

  // Mesial = lado voltado para a linha média.
  bool get _ladoEsquerdo => AnatomiaDente.ladoEsquerdoDoDesenho(numero);
  FaceDente get _faceEsquerda => _ladoEsquerdo ? FaceDente.distal : FaceDente.mesial;
  FaceDente get _faceDireita => _ladoEsquerdo ? FaceDente.mesial : FaceDente.distal;

  EstiloMarca _estilo(StatusTratamento s) => switch (s) {
        StatusTratamento.planejado => EstiloMarca.planejado,
        StatusTratamento.emAndamento => EstiloMarca.emAndamento,
        _ => EstiloMarca.solido,
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fator = AnatomiaDente.ehDeciduo(numero) ? _fatorDeciduo : 1.0;
    final raizes = AnatomiaDente.raizes(numero);

    final dentarias = marcacoes.where((r) => r.alvo == AlvoOdonto.dente).toList()
      ..sort((a, b) => a.condicao.prioridade.compareTo(b.condicao.prioridade));
    final ausente = dentarias.any(
      (r) => r.condicao == CondicaoOdonto.ausente || r.condicao == CondicaoOdonto.extraido,
    );
    final extracaoIndicada =
        dentarias.any((r) => r.condicao == CondicaoOdonto.extracaoIndicada);
    final comCoroa = dentarias.where((r) => r.condicao.pintaCoroa).toList();
    final corCoroa = comCoroa.isEmpty ? null : Color(comCoroa.first.condicao.corArgb);

    final principal = marcaPrincipal(marcacoes);
    final String? selo = principal == null
        ? null
        : (marcacoes.length > 1 ? '${principal.condicao.sigla}+' : principal.condicao.sigla);

    final marcasFaces = <FaceDente, MarcaFace>{
      for (final r in marcacoes)
        if (r.alvo == AlvoOdonto.face && r.face != null)
          r.face!: MarcaFace(
            cor: Color(r.condicao.corArgb),
            corListra:
                r.condicao.corSecundariaArgb == null ? null : Color(r.condicao.corSecundariaArgb!),
            estilo: _estilo(r.status),
          ),
    };

    final marcasRaiz = <MarcaRaiz>[
      for (final r in marcacoes)
        if (r.alvo == AlvoOdonto.raiz && r.raiz != null && raizes.contains(r.raiz!))
          MarcaRaiz(
            indice: raizes.indexOf(r.raiz!),
            cor: Color(r.condicao.corArgb),
            sigla: r.condicao.sigla,
            estilo: _estilo(r.status),
          ),
    ];

    // Marcas ortodônticas (Fase E)
    final marcasOrto = <MarcaOrtoDesenho>[
      for (final r in marcacoes)
        if (r.alvo == AlvoOdonto.dente && r.condicao.marcaOrtodontia != null)
          MarcaOrtoDesenho(
            tipo: r.condicao.marcaOrtodontia!,
            cor: Color(r.condicao.corArgb),
            estilo: _estilo(r.status),
          ),
    ];

    final desenho = DenteDesenho(
      numero: numero,
      fator: fator,
      apagado: ausente,
      xVermelho: extracaoIndicada,
      corCoroa: corCoroa,
      selo: selo,
      corSelo: principal == null ? Colors.blueGrey : Color(principal.condicao.corArgb),
      marcasRaiz: marcasRaiz,
      marcasOrto: marcasOrto,
      aoToqueCoroa: editavel ? () => aoToque(numero, null, null) : null,
      aoToqueRaiz: editavel && !ausente && !somenteCoroa
          ? (indice) => aoToque(numero, null, raizes[indice])
          : null,
    );

    final caixa = CaixaDente(
      tamanho: 38 * fator,
      topo: _faceTopo,
      base: _faceBase,
      esquerda: _faceEsquerda,
      direita: _faceDireita,
      marcas: marcasFaces,
      ausente: ausente,
      aoToqueFace: editavel && !ausente && !somenteCoroa
          ? (face) => aoToque(numero, face, null)
          : null,    );

    final rotulo = InkWell(
      onTap: editavel ? () => aoToque(numero, null, null) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$numero', style: tema.textTheme.labelMedium),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: superior ? [desenho, rotulo, caixa] : [caixa, rotulo, desenho],
      ),
    );
  }
}

/// Marcas de arcada ortodôntica (Fase E): Superior e Inferior em linhas separadas.
/// Com [aoAlterar] nulo, só mostra (visão de consulta ou sem permissão).
class _MarcasArcadaOrto extends StatelessWidget {
  final Map<ArcadaOdonto, List<TipoMarcaArcada>> marcasAtivas;
  final void Function(ArcadaOdonto, TipoMarcaArcada)? aoAlterar;

  const _MarcasArcadaOrto({required this.marcasAtivas, required this.aoAlterar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ortodontia (arcada)', style: tema.textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final arcada in ArcadaOdonto.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  child: Text('${arcada.rotulo}:', style: tema.textTheme.labelMedium),
                ),
                for (final tipo in TipoMarcaArcada.values)
                  FilterChip(
                    label: Text(tipo.rotulo),
                    selected: marcasAtivas[arcada]!.contains(tipo),
                    onSelected: aoAlterar == null ? null : (_) => aoAlterar!(arcada, tipo),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}