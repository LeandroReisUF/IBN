import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/features/odontograma/presentation/pages/aba_odontograma.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';
import 'package:ibn/features/plano_tratamento/domain/odontograma_do_plano.dart';
import 'package:ibn/features/plano_tratamento/domain/orcamento_visibilidade.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';
import 'package:ibn/features/plano_tratamento/presentation/cubit/plano_cubit.dart';
import 'package:ibn/features/plano_tratamento/presentation/cubit/plano_state.dart';

/// Plano de tratamento e orçamento (RF04.5, RN04), tudo inline.
/// Esta classe só **fornece** o Cubit.
class AbaPlanoTratamento extends StatelessWidget {
  final Paciente paciente;
  const AbaPlanoTratamento({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlanoCubit(
        repositorio: planoRepository,
        pacientes: pacientes,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
      )..carregar(),
      child: _PlanoView(paciente: paciente),
    );
  }
}

class _PlanoView extends StatefulWidget {
  final Paciente paciente;
  const _PlanoView({required this.paciente});

  @override
  State<_PlanoView> createState() => _PlanoViewState();
}

class _PlanoViewState extends State<_PlanoView> {
  Usuario get _usuario => auth.usuarioLogado!;
  bool get _podePlanejar => politicaAcesso.podePlanejarTratamento(_usuario, widget.paciente);

  /// Item cujo painel de encaminhamento está aberto (um por vez).
  String? _encaminhandoItemId;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String _nomeProcedimento(String id) => buscarProcedimento(id)?.nome ?? 'Procedimento';

  // ---------- ações ----------

  Future<String?> _criarPlano(String titulo) async {
    final erro = await context.read<PlanoCubit>().criarPlano(titulo);
    if (mounted) _aviso(erro ?? 'Plano criado. Adicione os procedimentos.');
    return erro;
  }

  Future<String?> _adicionarItem(PlanoTratamento plano, _DadosItem r) async {
    final erro = await context.read<PlanoCubit>().adicionarItem(
          plano,
          procedimentoId: r.procedimentoId,
          dente: r.dente,
          instrucoes: r.instrucoes,
          valorCentavos: r.valorCentavos,
          descontoCentavos: r.descontoCentavos,
        );
    if (mounted) _aviso(erro ?? 'Procedimento adicionado ao plano.');
    return erro;
  }

  Future<String?> _definirPagamento(
      PlanoTratamento plano, FormaPagamento forma, int parcelas) async {
    final erro = await context.read<PlanoCubit>().definirOrcamento(plano, forma, parcelas);
    if (mounted) _aviso(erro ?? 'Forma de pagamento definida.');
    return erro;
  }

  Future<String?> _encaminhar(
      PlanoTratamento plano, ItemPlano item, String executanteId, String instrucoes) async {
    final erro = await context
        .read<PlanoCubit>()
        .encaminhar(plano, item, executanteId, instrucoes: instrucoes);
    if (!mounted) return erro;
    _aviso(erro ??
        'Procedimento encaminhado. O executante vê só as instruções clínicas, sem valores.');
    if (erro == null) setState(() => _encaminhandoItemId = null);
    return erro;
  }

  Future<void> _realizar(PlanoTratamento plano, ItemPlano item) async {
    final erro = await context.read<PlanoCubit>().realizarMeuItem(plano, item);
    if (!mounted) return;
    _aviso(erro ?? 'Procedimento marcado como realizado.');
  }

  Future<void> _cancelar(PlanoTratamento plano, ItemPlano item) async {
    final cubit = context.read<PlanoCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar procedimento?'),
        content: const Text('Ele continua no plano como "Cancelado" e sai do total.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Cancelar procedimento')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final erro = await cubit.cancelarItem(plano, item);
    if (!mounted) return;
    if (erro != null) _aviso(erro);
  }

  Future<void> _executar(GuiaProcedimentoExecutante guia) async {
    final erro = await context.read<PlanoCubit>().executarGuia(guia);
    if (!mounted) return;
    _aviso(erro ?? 'Procedimento marcado como realizado.');
  }

  // ---------- visual ----------

  String _executante(String? id) =>
      id == null ? 'você' : (auth.buscarPorId(id)?.nome ?? 'profissional');

  Widget _linhaItem(PlanoTratamento plano, ItemPlano i) {
    final tema = Theme.of(context);
    final cancelado = i.status == StatusItem.cancelado;
    final riscado = cancelado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    final dente = i.dente == null ? '' : ' • dente ${i.dente}';
    final valores = 'Valor ${formatarReais(i.valorCentavos)}'
        '${i.descontoCentavos > 0 ? ' • desconto ${formatarReais(i.descontoCentavos)}' : ''}'
        ' • líquido ${formatarReais(i.liquidoCentavos)}';
    final situacao = i.status.rotulo +
        (i.executanteId == null ? '' : ' • executante: ${_executante(i.executanteId)}') +
        (i.realizadoEm == null ? '' : ' • realizado em ${formatarData(i.realizadoEm!)}');

    final acoes = <PopupMenuEntry<String>>[
      if (i.status == StatusItem.planejado) ...[
        const PopupMenuItem(value: 'encaminhar', child: Text('Encaminhar a outro dentista')),
        const PopupMenuItem(value: 'realizar', child: Text('Marcar como realizado')),
      ],
      if (i.status == StatusItem.planejado || i.status == StatusItem.encaminhado)
        const PopupMenuItem(value: 'cancelar', child: Text('Cancelar procedimento')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('${_nomeProcedimento(i.procedimentoId)}$dente', style: riscado),
          subtitle: Text(
            '$valores\n$situacao${i.instrucoes.isEmpty ? '' : '\nInstruções: ${i.instrucoes}'}',
            style: tema.textTheme.bodySmall?.copyWith(
              decoration: cancelado ? TextDecoration.lineThrough : null,
            ),
          ),
          isThreeLine: true,
          trailing: acoes.isEmpty
              ? null
              : PopupMenuButton<String>(
                  tooltip: 'Ações',
                  itemBuilder: (_) => acoes,
                  onSelected: (a) {
                    switch (a) {
                      case 'encaminhar':
                        setState(() => _encaminhandoItemId = i.id);
                      case 'realizar':
                        _realizar(plano, i);
                      default:
                        _cancelar(plano, i);
                    }
                  },
                ),
        ),
        if (_encaminhandoItemId == i.id && i.status == StatusItem.planejado)
          _PainelEncaminhar(
            key: ValueKey('enc-${i.id}'),
            executantes: context.read<PlanoCubit>().executantesPossiveis,
            instrucoesIniciais: i.instrucoes,
            aoEncaminhar: (executanteId, instrucoes) =>
                _encaminhar(plano, i, executanteId, instrucoes),
            aoCancelar: () => setState(() => _encaminhandoItemId = null),
          ),
      ],
    );
  }

  void _abrirOdontogramaDoPlano(PlanoTratamento plano) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Odontograma desejado • ${plano.titulo}')),
          body: AbaOdontograma(
            paciente: widget.paciente,
            chaveRegistros: chaveOdontogramaDoPlano(plano.id),
            aviso: 'Este odontograma mostra como se deseja que a boca fique ao fim do '
                'tratamento. Ele não altera o odontograma clínico do paciente.',
          ),
        ),
      ),
    );
  }

  Widget _odontogramaDoPlano(PlanoTratamento plano) {
    final chave = chaveOdontogramaDoPlano(plano.id);
    return ListenableBuilder(
      listenable: odontogramas,
      builder: (context, _) {
        final n = odontogramas.estadoAtual(chave).length;
        return Row(
          children: [
            Expanded(
              child: Text(
                n == 0
                    ? 'Odontograma desejado: ainda não preenchido.'
                    : 'Odontograma desejado: $n marcação(ões).',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _abrirOdontogramaDoPlano(plano),
              icon: const Icon(Icons.grid_view_outlined),
              label: Text(n == 0 ? 'Definir' : 'Ver / editar'),
            ),
          ],
        );
      },
    );
  }

  Widget _cartaoPlano(PlanoTratamento plano) {
    final tema = Theme.of(context);
    // RN04: só o criador e o Administrador veem valores; este cartão só é
    // montado com planos do próprio usuário, e esta checagem repete a regra.
    final veValores = orcamentoVisibilidade.podeVerValores(_usuario, plano);
    if (!veValores) return const SizedBox.shrink();
    final o = plano.orcamento;

    return Card(
      child: ExpansionTile(
        key: ValueKey('plano-${plano.id}'),
        initiallyExpanded: true,
        title: Text(plano.titulo),
        subtitle: Text(
          '${formatarData(plano.criadoEm)} • ${plano.itens.length} procedimento(s) • '
          'total ${formatarReais(plano.totalNegociadoCentavos)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plano.itens.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhum procedimento neste plano.'),
            )
          else
            for (final i in plano.itens) _linhaItem(plano, i),
          const Divider(),
          Text('Valor bruto: ${formatarReais(plano.totalBrutoCentavos)}',
              style: tema.textTheme.bodyMedium),
          Text('Descontos: ${formatarReais(plano.descontoTotalCentavos)}',
              style: tema.textTheme.bodyMedium),
          Text('Total negociado: ${formatarReais(plano.totalNegociadoCentavos)}',
              style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            o == null
                ? 'Forma de pagamento: não definida.'
                : 'Pagamento: ${o.forma.rotulo}'
                    '${o.parcelas > 1 ? ' em ${o.parcelas}x de ${formatarReais(plano.parcelaCentavos)}' : ' à vista'}',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          _odontogramaDoPlano(plano),
          const Divider(height: 24),
          _CompositorItem(
            key: ValueKey('item-${plano.id}'),
            usuario: _usuario,
            aoAdicionar: (r) => _adicionarItem(plano, r),
          ),
          const Divider(height: 24),
          _PainelPagamento(
            key: ValueKey('pag-${plano.id}-${o?.forma.name}-${o?.parcelas}'),
            inicial: o,
            aoSalvar: (forma, parcelas) => _definirPagamento(plano, forma, parcelas),
          ),
        ],
      ),
    );
  }

  /// A guia NÃO mostra nenhum valor, desconto, total ou pagamento (RN04).
  Widget _cartaoGuia(GuiaProcedimentoExecutante g) {
    final tema = Theme.of(context);
    final paciente = pacientes.buscarPorId(g.pacienteId);
    final dente = g.dente == null ? '' : ' • dente ${g.dente}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${_nomeProcedimento(g.procedimentoId)}$dente',
                      style: tema.textTheme.titleSmall),
                ),
                Chip(label: Text(g.status.rotulo)),
              ],
            ),
            if (paciente != null)
              Text('Paciente: ${paciente.nome}', style: tema.textTheme.bodySmall),
            if (g.encaminhadoEm != null)
              Text('Encaminhado em ${formatarData(g.encaminhadoEm!)}',
                  style: tema.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(g.instrucoes.isEmpty ? 'Sem instruções clínicas.' : g.instrucoes),
            if (g.status == StatusItem.encaminhado) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _executar(g),
                icon: const Icon(Icons.check),
                label: const Text('Marcar como realizado'),
              ),
            ],
            if (g.realizadoEm != null)
              Text('Realizado em ${formatarData(g.realizadoEm!)}',
                  style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(PlanoSuccess s) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_podePlanejar)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plano de tratamento', style: tema.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Você vê apenas os planos criados por você. Valores, descontos e pagamento '
                    'ficam só com o criador do plano e o Administrador (RN04): ao encaminhar um '
                    'procedimento, o outro dentista recebe só o procedimento, o dente e as '
                    'instruções clínicas. Nada é apagado: procedimentos não realizados podem ser '
                    'cancelados.',
                    style: tema.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _NovoPlano(aoCriar: _criarPlano),
                ],
              ),
            ),
          ),
        if (s.planos.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final p in s.planos) _cartaoPlano(p),
        ],
        if (s.guias.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Encaminhados a você', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final g in s.guias) _cartaoGuia(g),
        ],
        if (s.planos.isEmpty && s.guias.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum plano ou procedimento encaminhado.')),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlanoCubit, PlanoState>(
      builder: (context, state) => switch (state) {
        PlanoInitial() || PlanoLoading() => const Center(child: CircularProgressIndicator()),
        PlanoError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<PlanoCubit>().carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        final PlanoSuccess s => _conteudo(s),
      },
    );
  }
}

// ---------- painéis inline ----------

/// Linha "título + Criar plano".
class _NovoPlano extends StatefulWidget {
  final Future<String?> Function(String titulo) aoCriar;
  const _NovoPlano({required this.aoCriar});

  @override
  State<_NovoPlano> createState() => _NovoPlanoState();
}

class _NovoPlanoState extends State<_NovoPlano> {
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

  Future<void> _criar() async {
    final erro = await widget.aoCriar(_ctrl.text.trim());
    if (erro == null && mounted) _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Título do novo plano (ex.: Reabilitação superior) *',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _ctrl.text.trim().isEmpty ? null : _criar,
          icon: const Icon(Icons.add),
          label: const Text('Criar plano'),
        ),
      ],
    );
  }
}

class _DadosItem {
  final String procedimentoId;
  final int? dente;
  final String instrucoes;
  final int valorCentavos;
  final int descontoCentavos;
  const _DadosItem(
      this.procedimentoId, this.dente, this.instrucoes, this.valorCentavos, this.descontoCentavos);
}

/// Adicionar procedimento ao plano, sem janela.
class _CompositorItem extends StatefulWidget {
  final Usuario usuario;
  final Future<String?> Function(_DadosItem) aoAdicionar;

  const _CompositorItem({super.key, required this.usuario, required this.aoAdicionar});

  @override
  State<_CompositorItem> createState() => _CompositorItemState();
}

class _CompositorItemState extends State<_CompositorItem> {
  String? _procedimentoId;
  final _denteCtrl = TextEditingController();
  final _instrCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_denteCtrl, _valorCtrl, _descCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _denteCtrl.dispose();
    _instrCtrl.dispose();
    _valorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<Procedimento> get _procedimentos => procedimentos
      .where((p) => p.aceitaAlgumaDe(widget.usuario.perfil.especialidades))
      .toList();

  int? get _valor => lerCentavos(_valorCtrl.text);
  int get _desconto => _descCtrl.text.trim().isEmpty ? 0 : (lerCentavos(_descCtrl.text) ?? -1);
  int? get _dente => int.tryParse(_denteCtrl.text.trim());

  String? get _erro {
    if (_denteCtrl.text.trim().isNotEmpty && _dente == null) return 'Dente inválido.';
    if (_valorCtrl.text.trim().isNotEmpty && _valor == null) return 'Valor inválido.';
    if (_desconto < 0) return 'Desconto inválido.';
    if (_valor != null && _desconto > _valor!) return 'O desconto não pode passar do valor.';
    return null;
  }

  bool get _ok => _procedimentoId != null && _valor != null && _erro == null;

  Future<void> _adicionar() async {
    final erro = await widget.aoAdicionar(_DadosItem(
      _procedimentoId!,
      _dente,
      _instrCtrl.text.trim(),
      _valor!,
      _desconto,
    ));
    if (erro == null && mounted) {
      setState(() {
        _procedimentoId = null;
        _denteCtrl.clear();
        _instrCtrl.clear();
        _valorCtrl.clear();
        _descCtrl.clear();
      });
    }
  }

  Widget _campoNumero(TextEditingController c, String rotulo, double largura,
          {bool inteiro = false}) =>
      SizedBox(
        width: largura,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: !inteiro),
          inputFormatters: [
            inteiro
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
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
    final erro = _erro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Adicionar procedimento', style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String>(
                key: ValueKey('proc-$_procedimentoId'),
                initialValue: _procedimentoId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Procedimento *', isDense: true, border: OutlineInputBorder()),
                items: [
                  for (final p in _procedimentos)
                    DropdownMenuItem(value: p.id, child: Text(p.nome)),
                ],
                onChanged: (v) => setState(() => _procedimentoId = v),
              ),
            ),
            _campoNumero(_denteCtrl, 'Dente (FDI)', 110, inteiro: true),
            _campoNumero(_valorCtrl, 'Valor (R\$) *', 130),
            _campoNumero(_descCtrl, 'Desconto (R\$)', 130),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _instrCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Instruções clínicas (o executante verá)',
            border: OutlineInputBorder(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Valor e desconto ficam ocultos para quem executar o procedimento.',
              style: tema.textTheme.bodySmall),
        ),
        if (erro != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(erro, style: TextStyle(color: tema.colorScheme.error)),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _ok ? _adicionar : null,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar procedimento'),
        ),
      ],
    );
  }
}

/// Forma de pagamento: chips e, se parcelável, o número de parcelas.
class _PainelPagamento extends StatefulWidget {
  final Orcamento? inicial;
  final Future<String?> Function(FormaPagamento forma, int parcelas) aoSalvar;

  const _PainelPagamento({super.key, required this.inicial, required this.aoSalvar});

  @override
  State<_PainelPagamento> createState() => _PainelPagamentoState();
}

class _PainelPagamentoState extends State<_PainelPagamento> {
  late FormaPagamento _forma = widget.inicial?.forma ?? FormaPagamento.pix;
  late int _parcelas = widget.inicial?.parcelas ?? 1;

  bool get _parcela => _forma == FormaPagamento.cartaoCredito || _forma == FormaPagamento.boleto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forma de pagamento', style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final f in FormaPagamento.values)
              ChoiceChip(
                label: Text(f.rotulo),
                selected: _forma == f,
                onSelected: (_) => setState(() {
                  _forma = f;
                  if (!_parcela) _parcelas = 1;
                }),
              ),
          ],
        ),
        if (_parcela) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<int>(
              key: ValueKey('parcelas-$_parcelas'),
              initialValue: _parcelas,
              decoration: const InputDecoration(
                  labelText: 'Parcelas', isDense: true, border: OutlineInputBorder()),
              items: [for (var n = 1; n <= 12; n++) DropdownMenuItem(value: n, child: Text('${n}x'))],
              onChanged: (v) => setState(() => _parcelas = v ?? 1),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => widget.aoSalvar(_forma, _parcelas),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Salvar pagamento'),
        ),
      ],
    );
  }
}

/// Encaminhar um item a outro dentista, dentro do próprio item (RN04).
class _PainelEncaminhar extends StatefulWidget {
  final List<Usuario> executantes;
  final String instrucoesIniciais;
  final Future<String?> Function(String executanteId, String instrucoes) aoEncaminhar;
  final VoidCallback aoCancelar;

  const _PainelEncaminhar({
    super.key,
    required this.executantes,
    required this.instrucoesIniciais,
    required this.aoEncaminhar,
    required this.aoCancelar,
  });

  @override
  State<_PainelEncaminhar> createState() => _PainelEncaminharState();
}

class _PainelEncaminharState extends State<_PainelEncaminhar> {
  String? _executanteId;
  late final TextEditingController _instrCtrl =
      TextEditingController(text: widget.instrucoesIniciais);

  @override
  void dispose() {
    _instrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Encaminhar procedimento', style: tema.textTheme.titleSmall),
          Text(
            'O dentista escolhido recebe só o procedimento, o dente e as instruções abaixo, '
            'sem nenhum valor, e passa a ter o paciente vinculado.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (widget.executantes.isEmpty)
            const Text('Nenhum outro dentista disponível.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final u in widget.executantes)
                  ChoiceChip(
                    label: Text(u.nome),
                    selected: _executanteId == u.id,
                    onSelected: (_) => setState(() => _executanteId = u.id),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _instrCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Instruções clínicas',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _executanteId == null
                    ? null
                    : () => widget.aoEncaminhar(_executanteId!, _instrCtrl.text.trim()),
                child: const Text('Encaminhar'),
              ),
              TextButton(onPressed: widget.aoCancelar, child: const Text('Cancelar')),
            ],
          ),
        ],
      ),
    );
  }
}