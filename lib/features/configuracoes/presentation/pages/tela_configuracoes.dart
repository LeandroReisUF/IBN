import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/especialidade.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';
import 'package:ibn/features/configuracoes/domain/bloqueio_agenda.dart';
import 'package:ibn/features/configuracoes/presentation/cubit/configuracoes_cubit.dart';
import 'package:ibn/features/configuracoes/presentation/cubit/configuracoes_state.dart';
import 'package:flutter/services.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/configuracoes/domain/paleta_cores.dart';
import 'package:ibn/features/configuracoes/domain/area_dentista.dart';

/// Configurações da clínica (só Administrador). Esta classe só **fornece** o Cubit.
class TelaConfiguracoes extends StatelessWidget {
  const TelaConfiguracoes({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConfiguracoesCubit(
        repositorio: configuracaoClinica,
        agendaService: agenda,
        usuario: auth.usuarioLogado!,
      )..carregar(),
      child: const _ConfiguracoesView(),
    );
  }
}

void _aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}

Future<bool> _confirmar(BuildContext context, String titulo, String texto, String botao) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(botao)),
      ],
    ),
  );
  return r ?? false;
}

class _ConfiguracoesView extends StatelessWidget {
  const _ConfiguracoesView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfiguracoesCubit, ConfiguracoesState>(
      builder: (context, state) => switch (state) {
        ConfiguracoesInitial() || ConfiguracoesLoading() =>
          const Center(child: CircularProgressIndicator()),
        ConfiguracoesError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<ConfiguracoesCubit>().carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
                final ConfiguracoesSuccess s => DefaultTabController(
            length: 5,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Salas'),
                    Tab(text: 'Bloqueios'),
                    Tab(text: 'Procedimentos'),
                    Tab(text: 'Cores'),
                    Tab(text: 'Dentistas'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _AbaSalas(salas: s.salas),
                      _AbaBloqueios(salas: s.salas, bloqueios: s.bloqueios),
                      _AbaProcedimentos(procedimentos: s.procedimentos),
                      _AbaCores(cores: s.cores),
                      _AbaDentistas(areas: s.areasDentistas),
                    ],
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }
}

// ---------- salas ----------

class _AbaSalas extends StatelessWidget {
  final List<Sala> salas;
  const _AbaSalas({required this.salas});

  Future<void> _editar(BuildContext context, {Sala? sala}) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final r = await showDialog<Sala>(
      context: context,
      builder: (_) => _DialogoSala(sala: sala, numeroNovo: cubit.proximoNumeroSala),
    );
    if (r == null || !context.mounted) return;
    final erro = await cubit.salvarSala(r);
    if (context.mounted) _aviso(context, erro ?? 'Sala salva.');
  }

  Future<void> _alternarAtiva(BuildContext context, Sala s) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final erro = await cubit.definirSalaAtiva(s.numero, !s.ativa);
    if (context.mounted && erro != null) _aviso(context, erro);
  }

  Future<void> _excluir(BuildContext context, Sala s) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final ok = await _confirmar(
      context,
      'Excluir ${s.nome}?',
      'Os bloqueios dela também serão removidos. Sala que já teve agendamentos só pode ser desativada.',
      'Excluir',
    );
    if (!ok || !context.mounted) return;
    final erro = await cubit.excluirSala(s.numero);
    if (context.mounted) _aviso(context, erro ?? 'Sala excluída.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _editar(context),
            icon: const Icon(Icons.add),
            label: const Text('Nova sala'),
          ),
        ),
        const SizedBox(height: 8),
        for (final s in salas)
          Card(
            child: ListTile(
              title: Text(s.nome),
              subtitle: Text(
                '${s.exclusiva ? 'Exclusiva' : 'Revezamento'} • '
                '${s.especialidadesPermitidas.map((e) => e.rotulo).join(', ')}',
              ),
              leading: Icon(s.ativa ? Icons.meeting_room_outlined : Icons.no_meeting_room_outlined),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!s.ativa) const Chip(label: Text('Desativada')),
                  PopupMenuButton<String>(
                    tooltip: 'Ações',
                    onSelected: (a) => switch (a) {
                      'editar' => _editar(context, sala: s),
                      'ativa' => _alternarAtiva(context, s),
                      _ => _excluir(context, s),
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'ativa', child: Text(s.ativa ? 'Desativar' : 'Reativar')),
                      const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DialogoSala extends StatefulWidget {
  final Sala? sala;
  final int numeroNovo;
  const _DialogoSala({required this.sala, required this.numeroNovo});

  @override
  State<_DialogoSala> createState() => _DialogoSalaState();
}

class _DialogoSalaState extends State<_DialogoSala> {
  late final TextEditingController _nomeCtrl =
      TextEditingController(text: widget.sala?.nome ?? '');
  late final Set<Especialidade> _areas = {...?widget.sala?.especialidadesPermitidas};
  late bool _exclusiva = widget.sala?.exclusiva ?? false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  bool get _ok => _nomeCtrl.text.trim().isNotEmpty && _areas.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(widget.sala == null ? 'Nova sala' : 'Editar ${widget.sala!.nome}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text('Áreas que podem usar a sala * (RN01)', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final e in Especialidade.values)
                    FilterChip(
                      label: Text(e.rotulo),
                      selected: _areas.contains(e),
                      onSelected: (v) => setState(() => v ? _areas.add(e) : _areas.remove(e)),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Uso exclusivo (sem revezamento)'),
                value: _exclusiva,
                onChanged: (v) => setState(() => _exclusiva = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ok
              ? () => Navigator.of(context).pop(Sala(
                    numero: widget.sala?.numero ?? widget.numeroNovo,
                    nome: _nomeCtrl.text.trim(),
                    exclusiva: _exclusiva,
                    especialidadesPermitidas: {..._areas},
                    ativa: widget.sala?.ativa ?? true,
                  ))
              : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ---------- bloqueios ----------

class _AbaBloqueios extends StatelessWidget {
  final List<Sala> salas;
  final List<BloqueioAgenda> bloqueios;
  const _AbaBloqueios({required this.salas, required this.bloqueios});

  String _nomeSala(int n) => salas.where((s) => s.numero == n).firstOrNull?.nome ?? 'Sala $n';

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  Future<void> _editar(BuildContext context, {BloqueioAgenda? bloqueio}) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final r = await showDialog<BloqueioAgenda>(
      context: context,
      builder: (_) => _DialogoBloqueio(salas: salas, bloqueio: bloqueio, idNovo: cubit.novoId()),
    );
    if (r == null || !context.mounted) return;
    final erro = await cubit.salvarBloqueio(r);
    if (!context.mounted) return;
    if (erro != null) {
      _aviso(context, erro);
      return;
    }
    final afetados = cubit.agendamentosAfetados(r);
    _aviso(
      context,
      afetados == 0
          ? 'Bloqueio salvo.'
          : 'Bloqueio salvo. Atenção: $afetados agendamento(s) já marcado(s) nesse período '
              'continuam na agenda; reagende-os.',
    );
  }

  Future<void> _desbloquear(BuildContext context, BloqueioAgenda b) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final ok = await _confirmar(
      context,
      'Desbloquear ${_nomeSala(b.salaNumero)}?',
      'A sala volta a aceitar agendamentos nesse período.',
      'Desbloquear',
    );
    if (!ok || !context.mounted) return;
    final erro = await cubit.excluirBloqueio(b.id);
    if (context.mounted) _aviso(context, erro ?? 'Sala desbloqueada.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: salas.isEmpty ? null : () => _editar(context),
            icon: const Icon(Icons.lock_clock_outlined),
            label: const Text('Novo bloqueio'),
          ),
        ),
        const SizedBox(height: 8),
        if (bloqueios.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhum bloqueio.')))
        else
          for (final b in bloqueios)
            Card(
              child: ListTile(
                leading: const Icon(Icons.block_outlined),
                title: Text('${_nomeSala(b.salaNumero)} • ${b.motivo}'),
                subtitle: Text('${_dataHora(b.inicio)} até ${_dataHora(b.fim)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editar(context, bloqueio: b),
                    ),
                    TextButton(onPressed: () => _desbloquear(context, b), child: const Text('Desbloquear')),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _DialogoBloqueio extends StatefulWidget {
  final List<Sala> salas;
  final BloqueioAgenda? bloqueio;
  final String idNovo;
  const _DialogoBloqueio({required this.salas, required this.bloqueio, required this.idNovo});

  @override
  State<_DialogoBloqueio> createState() => _DialogoBloqueioState();
}

class _DialogoBloqueioState extends State<_DialogoBloqueio> {
  late int _sala;
  late DateTime _inicio;
  late DateTime _fim;
  final _motivoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final b = widget.bloqueio;
    final hoje = DateTime.now();
    _sala = b?.salaNumero ?? widget.salas.first.numero;
    _inicio = b?.inicio ?? DateTime(hoje.year, hoje.month, hoje.day, 8);
    _fim = b?.fim ?? DateTime(hoje.year, hoje.month, hoje.day, 18);
    _motivoCtrl.text = b?.motivo ?? '';
    _motivoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _escolher(DateTime atual) async {
    final d = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return null;
    final h = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(atual));
    if (h == null || !mounted) return null;
    return DateTime(d.year, d.month, d.day, h.hour, h.minute);
  }

  bool get _periodoOk => _fim.isAfter(_inicio);
  bool get _ok => _periodoOk && _motivoCtrl.text.trim().length >= 3;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    String rotulo(String t, DateTime d) => '$t: ${formatarData(d)} ${formatarHora(d)}';
    return AlertDialog(
      title: Text(widget.bloqueio == null ? 'Novo bloqueio' : 'Editar bloqueio'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _sala,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sala', border: OutlineInputBorder()),
                items: [
                  for (final s in widget.salas) DropdownMenuItem(value: s.numero, child: Text(s.nome)),
                ],
                onChanged: (v) => setState(() => _sala = v ?? _sala),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await _escolher(_inicio);
                  if (d != null) setState(() => _inicio = d);
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(rotulo('Início', _inicio)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await _escolher(_fim);
                  if (d != null) setState(() => _fim = d);
                },
                icon: const Icon(Icons.event_available_outlined),
                label: Text(rotulo('Fim', _fim)),
              ),
              if (!_periodoOk)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('O fim deve ser depois do início.',
                      style: TextStyle(color: tema.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo * (ex.: manutenção do equipamento)',
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
          onPressed: _ok
              ? () => Navigator.of(context).pop(BloqueioAgenda(
                    id: widget.bloqueio?.id ?? widget.idNovo,
                    salaNumero: _sala,
                    inicio: _inicio,
                    fim: _fim,
                    motivo: _motivoCtrl.text.trim(),
                  ))
              : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
// ---------- procedimentos ----------

class _AbaProcedimentos extends StatelessWidget {
  final List<Procedimento> procedimentos;
  const _AbaProcedimentos({required this.procedimentos});

  Future<void> _editar(BuildContext context, {Procedimento? procedimento}) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final r = await showDialog<Procedimento>(
      context: context,
      builder: (_) => _DialogoProcedimento(procedimento: procedimento, idNovo: cubit.novoId()),
    );
    if (r == null || !context.mounted) return;
    final erro = await cubit.salvarProcedimento(r);
    if (context.mounted) _aviso(context, erro ?? 'Procedimento salvo.');
  }

  Future<void> _alternarAtivo(BuildContext context, Procedimento p) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final erro = await cubit.definirProcedimentoAtivo(p.id, !p.ativo);
    if (context.mounted && erro != null) _aviso(context, erro);
  }

  Future<void> _excluir(BuildContext context, Procedimento p) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final ok = await _confirmar(
      context,
      'Excluir ${p.nome}?',
      'Procedimento que já foi usado em agenda, plano ou odontograma só pode ser desativado.',
      'Excluir',
    );
    if (!ok || !context.mounted) return;
    final erro = await cubit.excluirProcedimento(p.id);
    if (context.mounted) _aviso(context, erro ?? 'Procedimento excluído.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _editar(context),
            icon: const Icon(Icons.add),
            label: const Text('Novo procedimento'),
          ),
        ),
        const SizedBox(height: 8),
        for (final p in procedimentos)
          Card(
            child: ListTile(
              leading: const Icon(Icons.medical_services_outlined),
              title: Text(p.nome),
              subtitle: Text('${p.duracaoMinutos} min • ${p.rotuloAreas}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!p.ativo) const Chip(label: Text('Desativado')),
                  PopupMenuButton<String>(
                    tooltip: 'Ações',
                    onSelected: (a) => switch (a) {
                      'editar' => _editar(context, procedimento: p),
                      'ativo' => _alternarAtivo(context, p),
                      _ => _excluir(context, p),
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'ativo', child: Text(p.ativo ? 'Desativar' : 'Reativar')),
                      const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DialogoProcedimento extends StatefulWidget {
  final Procedimento? procedimento;
  final String idNovo;
  const _DialogoProcedimento({required this.procedimento, required this.idNovo});

  @override
  State<_DialogoProcedimento> createState() => _DialogoProcedimentoState();
}

class _DialogoProcedimentoState extends State<_DialogoProcedimento> {
  late final TextEditingController _nomeCtrl =
      TextEditingController(text: widget.procedimento?.nome ?? '');
  late final TextEditingController _duracaoCtrl =
      TextEditingController(text: '${widget.procedimento?.duracaoMinutos ?? 30}');
  late final Set<Especialidade> _areas = {...?widget.procedimento?.especialidades};

  @override
  void initState() {
    super.initState();
    _nomeCtrl.addListener(() => setState(() {}));
    _duracaoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _duracaoCtrl.dispose();
    super.dispose();
  }

  int? get _duracao => int.tryParse(_duracaoCtrl.text);

  bool get _ok =>
      _nomeCtrl.text.trim().isNotEmpty &&
      _areas.isNotEmpty &&
      (_duracao ?? 0) >= 5 &&
      (_duracao ?? 0) <= 480;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(widget.procedimento == null ? 'Novo procedimento' : 'Editar procedimento'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _duracaoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Duração (min, de 5 a 480) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Áreas (uma ou mais) *', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final e in Especialidade.values)
                    FilterChip(
                      label: Text(e.rotulo),
                      selected: _areas.contains(e),
                      onSelected: (v) => setState(() => v ? _areas.add(e) : _areas.remove(e)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ok
              ? () => Navigator.of(context).pop(Procedimento(
                    id: widget.procedimento?.id ?? widget.idNovo,
                    nome: _nomeCtrl.text.trim(),
                    especialidades: {..._areas},
                    duracaoMinutos: _duracao!,
                    ativo: widget.procedimento?.ativo ?? true,
                  ))
              : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
// ---------- cores por tipo de profissional ----------

class _AbaCores extends StatelessWidget {
  final Map<Perfil, int> cores;
  const _AbaCores({required this.cores});

  Future<void> _escolher(BuildContext context, Perfil perfil, int cor) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final erro = await cubit.definirCorPerfil(perfil, cor);
    if (context.mounted && erro != null) _aviso(context, erro);
  }

  Future<void> _restaurar(BuildContext context) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final ok = await _confirmar(
      context,
      'Restaurar cores padrão?',
      'Todos os tipos de profissional voltam às cores originais.',
      'Restaurar',
    );
    if (!ok || !context.mounted) return;
    final erro = await cubit.restaurarCores();
    if (context.mounted) _aviso(context, erro ?? 'Cores restauradas.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'A cor de cada tipo de profissional aparece na agenda e no painel. '
          'Duas cores iguais não são permitidas; as esmaecidas já estão em uso.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _restaurar(context),
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar cores padrão'),
          ),
        ),
        const SizedBox(height: 8),
        for (final e in cores.entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 8, backgroundColor: Color(e.value)),
                      const SizedBox(width: 8),
                      Text(e.key.rotulo, style: tema.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cor in paletaCoresTag)
                        Opacity(
                          opacity: cores.entries.any((o) => o.key != e.key && o.value == cor) ? 0.3 : 1,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _escolher(context, e.key, cor),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(cor),
                              child: cor == e.value
                                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
// ---------- áreas do dentista ----------

class _AbaDentistas extends StatelessWidget {
  final Map<String, Set<AreaDentista>> areas;
  const _AbaDentistas({required this.areas});

  Future<void> _alterar(BuildContext context, String id, AreaDentista area, bool tem) async {
    final cubit = context.read<ConfiguracoesCubit>();
    final erro = await cubit.definirAreaDentista(id, area, tem);
    if (context.mounted && erro != null) _aviso(context, erro);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final dentistas =
        auth.profissionaisSaude.where((u) => u.perfil == Perfil.dentista).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ortodontia e HOF só aparecem no prontuário do dentista marcado como especialista '
          'na área. Se a área for removida, os registros já feitos continuam guardados.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final u in dentistas)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.nome, style: tema.textTheme.titleSmall),
                  Text(u.registroFormatado ?? 'Registro no conselho não cadastrado',
                      style: tema.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final a in AreaDentista.values)
                        FilterChip(
                          label: Text(a.rotulo),
                          selected: areas[u.id]?.contains(a) ?? false,
                          onSelected: (v) => _alterar(context, u.id, a, v),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}