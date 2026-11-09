import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';
import 'package:ibn/features/plano_tratamento/domain/orcamento_visibilidade.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';
import 'package:ibn/features/plano_tratamento/presentation/cubit/plano_cubit.dart';
import 'package:ibn/features/plano_tratamento/presentation/cubit/plano_state.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/features/odontograma/presentation/pages/aba_odontograma.dart';
import 'package:ibn/features/plano_tratamento/domain/odontograma_do_plano.dart';

/// Plano de tratamento e orçamento (RF04.5, RN04). Esta classe só **fornece** o Cubit.
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

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String _nomeProcedimento(String id) => buscarProcedimento(id)?.nome ?? 'Procedimento';

  // ---------- ações ----------

  Future<void> _novoPlano() async {
    final cubit = context.read<PlanoCubit>();
    final titulo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoTitulo(),
    );
    if (titulo == null || !mounted) return;
    final erro = await cubit.criarPlano(titulo);
    if (!mounted) return;
    _aviso(erro ?? 'Plano criado. Adicione os procedimentos.');
  }

  Future<void> _novoItem(PlanoTratamento plano) async {
    final cubit = context.read<PlanoCubit>();
    final r = await showDialog<_DadosItem>(
      context: context,
      builder: (_) => _DialogoItem(usuario: _usuario),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.adicionarItem(
      plano,
      procedimentoId: r.procedimentoId,
      dente: r.dente,
      instrucoes: r.instrucoes,
      valorCentavos: r.valorCentavos,
      descontoCentavos: r.descontoCentavos,
    );
    if (!mounted) return;
    _aviso(erro ?? 'Procedimento adicionado ao plano.');
  }

  Future<void> _pagamento(PlanoTratamento plano) async {
    final cubit = context.read<PlanoCubit>();
    final r = await showDialog<Orcamento>(
      context: context,
      builder: (_) => _DialogoPagamento(inicial: plano.orcamento),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.definirOrcamento(plano, r.forma, r.parcelas);
    if (!mounted) return;
    _aviso(erro ?? 'Forma de pagamento definida.');
  }

  Future<void> _encaminhar(PlanoTratamento plano, ItemPlano item) async {
    final cubit = context.read<PlanoCubit>();
    final r = await showDialog<({String executanteId, String instrucoes})>(
      context: context,
      builder: (_) => _DialogoEncaminhar(
        executantes: cubit.executantesPossiveis,
        instrucoesIniciais: item.instrucoes,
      ),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.encaminhar(plano, item, r.executanteId, instrucoes: r.instrucoes);
    if (!mounted) return;
    _aviso(erro ?? 'Procedimento encaminhado. O executante vê só as instruções clínicas, sem valores.');
  }

  Future<void> _realizar(PlanoTratamento plano, ItemPlano item) async {
    final cubit = context.read<PlanoCubit>();
    final erro = await cubit.realizarMeuItem(plano, item);
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
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cancelar procedimento')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final erro = await cubit.cancelarItem(plano, item);
    if (!mounted) return;
    if (erro != null) _aviso(erro);
  }

  Future<void> _executar(GuiaProcedimentoExecutante guia) async {
    final cubit = context.read<PlanoCubit>();
    final erro = await cubit.executarGuia(guia);
    if (!mounted) return;
    _aviso(erro ?? 'Procedimento marcado como realizado.');
  }

  // ---------- visual ----------

  String _executante(String? id) => id == null ? 'você' : (auth.buscarPorId(id)?.nome ?? 'profissional');

  Widget _linhaItem(PlanoTratamento plano, ItemPlano i) {
    final tema = Theme.of(context);
    final cancelado = i.status == StatusItem.cancelado;
    final riscado = cancelado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    final dente = i.dente == null ? '' : ' • dente ${i.dente}';
    final valores = 'Valor ${formatarReais(i.valorCentavos)}'
        '${i.descontoCentavos > 0 ? ' • desconto ${formatarReais(i.descontoCentavos)}' : ''}'
        ' • líquido ${formatarReais(i.liquidoCentavos)}';
    final situacao = '${i.status.rotulo}'
        '${i.executanteId == null ? '' : ' • executante: ${_executante(i.executanteId)}'}'
        '${i.realizadoEm == null ? '' : ' • realizado em ${formatarData(i.realizadoEm!)}'}';

    final acoes = <PopupMenuEntry<String>>[
      if (i.status == StatusItem.planejado) ...[
        const PopupMenuItem(value: 'encaminhar', child: Text('Encaminhar a outro dentista')),
        const PopupMenuItem(value: 'realizar', child: Text('Marcar como realizado')),
      ],
      if (i.status == StatusItem.planejado || i.status == StatusItem.encaminhado)
        const PopupMenuItem(value: 'cancelar', child: Text('Cancelar procedimento')),
    ];

    return ListTile(
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
              onSelected: (a) => switch (a) {
                'encaminhar' => _encaminhar(plano, i),
                'realizar' => _realizar(plano, i),
                _ => _cancelar(plano, i),
              },
            ),
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
          Text('Valor bruto: ${formatarReais(plano.totalBrutoCentavos)}', style: tema.textTheme.bodyMedium),
          Text('Descontos: ${formatarReais(plano.descontoTotalCentavos)}', style: tema.textTheme.bodyMedium),
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
          const SizedBox(height: 8),
          _odontogramaDoPlano(plano),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _novoItem(plano),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar procedimento'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pagamento(plano),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Forma de pagamento'),
              ),
            ],
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
            if (paciente != null) Text('Paciente: ${paciente.nome}', style: tema.textTheme.bodySmall),
            if (g.encaminhadoEm != null)
              Text('Encaminhado em ${formatarData(g.encaminhadoEm!)}', style: tema.textTheme.bodySmall),
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
              Text('Realizado em ${formatarData(g.realizadoEm!)}', style: tema.textTheme.bodySmall),
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
                  FilledButton.icon(
                    onPressed: _novoPlano,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo plano'),
                  ),
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

// ---------- diálogos ----------

class _DialogoTitulo extends StatefulWidget {
  const _DialogoTitulo();

  @override
  State<_DialogoTitulo> createState() => _DialogoTituloState();
}

class _DialogoTituloState extends State<_DialogoTitulo> {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo plano de tratamento'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            labelText: 'Título (ex.: Reabilitação superior) *',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ctrl.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Criar'),
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
  const _DadosItem(this.procedimentoId, this.dente, this.instrucoes, this.valorCentavos, this.descontoCentavos);
}

class _DialogoItem extends StatefulWidget {
  final Usuario usuario;
  const _DialogoItem({required this.usuario});

  @override
  State<_DialogoItem> createState() => _DialogoItemState();
}

class _DialogoItemState extends State<_DialogoItem> {
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

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final erro = _erro;
    return AlertDialog(
      title: const Text('Adicionar procedimento'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _procedimentoId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Procedimento *', border: OutlineInputBorder()),
                items: [
                  for (final p in _procedimentos) DropdownMenuItem(value: p.id, child: Text(p.nome)),
                ],
                onChanged: (v) => setState(() => _procedimentoId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _denteCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Dente (número FDI, opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instrCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instruções clínicas (o executante verá)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Valor (R\$) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _descCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Desconto (R\$)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Valor e desconto ficam ocultos para quem executar o procedimento.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ),
              if (erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(erro, style: TextStyle(color: tema.colorScheme.error)),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ok
              ? () => Navigator.of(context).pop(_DadosItem(
                    _procedimentoId!,
                    _dente,
                    _instrCtrl.text.trim(),
                    _valor!,
                    _desconto,
                  ))
              : null,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _DialogoPagamento extends StatefulWidget {
  final Orcamento? inicial;
  const _DialogoPagamento({this.inicial});

  @override
  State<_DialogoPagamento> createState() => _DialogoPagamentoState();
}

class _DialogoPagamentoState extends State<_DialogoPagamento> {
  late FormaPagamento _forma = widget.inicial?.forma ?? FormaPagamento.pix;
  late int _parcelas = widget.inicial?.parcelas ?? 1;

  bool get _parcela => _forma == FormaPagamento.cartaoCredito || _forma == FormaPagamento.boleto;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forma de pagamento'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<FormaPagamento>(
              initialValue: _forma,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Forma', border: OutlineInputBorder()),
              items: [
                for (final f in FormaPagamento.values) DropdownMenuItem(value: f, child: Text(f.rotulo)),
              ],
              onChanged: (v) => setState(() {
                _forma = v ?? _forma;
                if (!_parcela) _parcelas = 1;
              }),
            ),
            if (_parcela) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _parcelas,
                decoration: const InputDecoration(labelText: 'Parcelas', border: OutlineInputBorder()),
                items: [for (var n = 1; n <= 12; n++) DropdownMenuItem(value: n, child: Text('${n}x'))],
                onChanged: (v) => setState(() => _parcelas = v ?? 1),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(Orcamento(forma: _forma, parcelas: _parcelas)),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _DialogoEncaminhar extends StatefulWidget {
  final List<Usuario> executantes;
  final String instrucoesIniciais;
  const _DialogoEncaminhar({required this.executantes, required this.instrucoesIniciais});

  @override
  State<_DialogoEncaminhar> createState() => _DialogoEncaminharState();
}

class _DialogoEncaminharState extends State<_DialogoEncaminhar> {
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
    return AlertDialog(
      title: const Text('Encaminhar procedimento'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O dentista escolhido recebe só o procedimento, o dente e as instruções abaixo, '
                'sem nenhum valor, e passa a ter o paciente vinculado.',
                style: tema.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _executanteId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dentista *', border: OutlineInputBorder()),
                items: [
                  for (final u in widget.executantes) DropdownMenuItem(value: u.id, child: Text(u.nome)),
                ],
                onChanged: (v) => setState(() => _executanteId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instrCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Instruções clínicas',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _executanteId == null
              ? null
              : () => Navigator.of(context).pop((
                    executanteId: _executanteId!,
                    instrucoes: _instrCtrl.text.trim(),
                  )),
          child: const Text('Encaminhar'),
        ),
      ],
    );
  }
}