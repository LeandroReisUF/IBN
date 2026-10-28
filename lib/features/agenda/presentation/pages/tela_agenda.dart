import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/paciente_repository.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/agenda/presentation/cubit/agendamento_cubit.dart';
import 'package:ibn/features/agenda/presentation/cubit/agendamento_state.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'tela_form_agendamento.dart';

enum _Periodo { dia, semana, mes }

enum _Visao { geral, sala, profissional }

/// Agenda da clínica (RF02). Esta classe só **fornece** o Cubit;
/// o desenho da tela está em [_AgendaView].
class TelaAgenda extends StatelessWidget {
  const TelaAgenda({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AgendamentoCubit(
        servico: agenda,
        usuario: auth.usuarioLogado!,
      )..carregar(),
      child: const _AgendaView(),
    );
  }
}

class _AgendaView extends StatefulWidget {
  const _AgendaView();

  @override
  State<_AgendaView> createState() => _AgendaViewState();
}

/// Aqui fica só o estado **de tela** (qual dia/semana/mês, qual visão, qual
/// filtro). Os dados da agenda vêm do Cubit.
class _AgendaViewState extends State<_AgendaView> {
  DateTime _data = soData(DateTime.now());
  _Periodo _periodo = _Periodo.dia;
  _Visao _visao = _Visao.geral;
  int _salaFiltro = 1;
  String? _profFiltro;

  // ---------- período ----------

  DateTime get _inicioPeriodo => switch (_periodo) {
        _Periodo.dia => _data,
        _Periodo.semana =>
          DateTime(_data.year, _data.month, _data.day - (_data.weekday - 1)),
        _Periodo.mes => DateTime(_data.year, _data.month, 1),
      };

  DateTime get _fimPeriodo {
    final ini = _inicioPeriodo;
    return switch (_periodo) {
      _Periodo.dia => DateTime(ini.year, ini.month, ini.day + 1),
      _Periodo.semana => DateTime(ini.year, ini.month, ini.day + 7),
      _Periodo.mes => DateTime(ini.year, ini.month + 1, 1),
    };
  }

  String get _titulo {
    if (_periodo == _Periodo.dia) {
      return '${nomesDiaSemana[_data.weekday - 1]}, ${formatarData(_data)}';
    }
    if (_periodo == _Periodo.semana) {
      final ultimo = DateTime(_fimPeriodo.year, _fimPeriodo.month, _fimPeriodo.day - 1);
      return '${formatarData(_inicioPeriodo)} – ${formatarData(ultimo)}';
    }
    return '${nomesMes[_data.month - 1]} de ${_data.year}';
  }

  void _mover(int passo) {
    setState(() {
      _data = switch (_periodo) {
        _Periodo.dia => DateTime(_data.year, _data.month, _data.day + passo),
        _Periodo.semana => DateTime(_data.year, _data.month, _data.day + 7 * passo),
        _Periodo.mes => DateTime(_data.year, _data.month + passo, 1),
      };
    });
  }

  Future<void> _escolherData() async {
    final nova = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nova != null) setState(() => _data = soData(nova));
  }

  // ---------- ações ----------

  void _abrirForm({Agendamento? agendamento}) {
    // O formulário ainda usa o AgendaService direto (ele fica numa rota fora do
    // BlocProvider). Como o Cubit escuta o serviço, a lista atualiza sozinha.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaFormAgendamento(
          agendamento: agendamento,
          dataInicial: _data,
        ),
      ),
    );
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// RN03: o nome só aparece se o usuário puder ver aquele paciente.
  String _nomePaciente(Agendamento a, Usuario usuario) {
    final p = pacientes.buscarPorId(a.pacienteId);
    if (p == null) return 'Paciente removido';
    return politicaAcesso.podeVerPaciente(usuario, p) ? p.nome : 'Paciente sem acesso';
  }

  Color _corStatus(StatusAgendamento s) => switch (s) {
        StatusAgendamento.agendado => Colors.blueGrey,
        StatusAgendamento.confirmadoWhatsapp => Colors.green,
        StatusAgendamento.naRecepcao => Colors.orange,
        StatusAgendamento.emAtendimento => Colors.blue,
        StatusAgendamento.atendido => Colors.grey,
        StatusAgendamento.faltouDesmarcou => Colors.red,
      };

  void _abrirDetalhe(Agendamento a) {
    final usuario = auth.usuarioLogado!;
    final proc = buscarProcedimento(a.procedimentoId);
    final prof = auth.buscarPorId(a.profissionalId);
    final sala = buscarSala(a.salaNumero);
    final statusPermitidos = politicaAcesso.statusPermitidos(usuario, a);
    final podeAgendar = politicaAcesso.podeAgendar(usuario);
    final tema = Theme.of(context);
    // Pega o Cubit AQUI, antes de abrir a folha (ela fica fora do BlocProvider).
    final cubit = context.read<AgendamentoCubit>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_nomePaciente(a, usuario), style: tema.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${formatarData(a.inicio)}  •  ${formatarHora(a.inicio)} – ${formatarHora(a.fim)}'),
              Text(proc == null ? 'Procedimento' : proc.nome),
              Text('${prof == null ? 'Profissional' : prof.nome}  •  ${sala == null ? 'Sala' : sala.nome}'),
              if (a.observacoes.isNotEmpty) Text('Obs.: ${a.observacoes}'),
              if (statusPermitidos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Status', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final st in statusPermitidos)
                      ChoiceChip(
                        label: Text(st.rotulo),
                        selected: st == a.status,
                        onSelected: (_) async {
                          Navigator.of(ctx).pop();
                          final erro = await cubit.mudarStatus(a.id, st);
                          if (erro != null && mounted) _aviso(erro);
                        },
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 16),
                Chip(label: Text(a.status.rotulo)),
              ],
              if (podeAgendar) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _abrirForm(agendamento: a);
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Editar / reagendar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- visual ----------

  Widget _cabecalho(bool global, List<Usuario> profissionais, String profId) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Anterior',
                onPressed: () => _mover(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              TextButton(
                onPressed: _escolherData,
                child: Text(_titulo, style: tema.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Próximo',
                onPressed: () => _mover(1),
                icon: const Icon(Icons.chevron_right),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _data = soData(DateTime.now())),
                child: const Text('Hoje'),
              ),
              SegmentedButton<_Periodo>(
                segments: const [
                  ButtonSegment(value: _Periodo.dia, label: Text('Dia')),
                  ButtonSegment(value: _Periodo.semana, label: Text('Semana')),
                  ButtonSegment(value: _Periodo.mes, label: Text('Mês')),
                ],
                selected: {_periodo},
                onSelectionChanged: (s) => setState(() => _periodo = s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (global)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_Visao>(
                  segments: const [
                    ButtonSegment(value: _Visao.geral, label: Text('Visão geral')),
                    ButtonSegment(value: _Visao.sala, label: Text('Por sala')),
                    ButtonSegment(value: _Visao.profissional, label: Text('Por profissional')),
                  ],
                  selected: {_visao},
                  onSelectionChanged: (s) => setState(() => _visao = s.first),
                ),
                if (_visao == _Visao.sala)
                  DropdownButton<int>(
                    value: _salaFiltro,
                    items: [
                      for (final s in salas)
                        DropdownMenuItem(value: s.numero, child: Text(s.nome)),
                    ],
                    onChanged: (v) => setState(() => _salaFiltro = v ?? 1),
                  ),
                if (_visao == _Visao.profissional)
                  DropdownButton<String>(
                    value: profId,
                    items: [
                      for (final u in profissionais)
                        DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.nome} • ${u.perfil.rotulo}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _profFiltro = v),
                  ),
              ],
            )
          else
            Text('Você vê apenas os seus atendimentos.', style: tema.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _cartao(Agendamento a, Usuario usuario) {
    final proc = buscarProcedimento(a.procedimentoId);
    final prof = auth.buscarPorId(a.profissionalId);
    final sala = buscarSala(a.salaNumero);
    final tema = Theme.of(context);
    final cor = _corStatus(a.status);
    final desmarcado = !a.status.ocupaHorario;
    final linhaDetalhe = [
      proc == null ? 'Procedimento' : proc.nome,
      prof == null ? 'Profissional' : prof.nome,
      sala == null ? 'Sala' : sala.nome,
    ].join('  •  ');

    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(formatarHora(a.inicio), style: tema.textTheme.titleSmall),
              Text(formatarHora(a.fim), style: tema.textTheme.bodySmall),
            ],
          ),
        ),
        title: Text(
          _nomePaciente(a, usuario),
          style: desmarcado
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Text(linhaDetalhe),
        trailing: Chip(
          label: Text(a.status.rotulo),
          backgroundColor: cor.withValues(alpha: 0.15),
          side: BorderSide.none,
        ),
        onTap: () => _abrirDetalhe(a),
      ),
    );
  }

  Widget _listaDeAgendamentos(List<Agendamento> lista, Usuario usuario) {
    if (lista.isEmpty) {
      return const Center(child: Text('Nenhum agendamento neste período.'));
    }
    final porDia = <DateTime, List<Agendamento>>{};
    for (final a in lista) {
      porDia.putIfAbsent(soData(a.inicio), () => []).add(a);
    }
    final dias = porDia.keys.toList()..sort();
    final tema = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        for (final dia in dias) ...[
          if (_periodo == _Periodo.semana)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                '${nomesDiaSemana[dia.weekday - 1]}, ${formatarData(dia)}',
                style: tema.textTheme.titleSmall,
              ),
            ),
          for (final a in porDia[dia]!) _cartao(a, usuario),
        ],
      ],
    );
  }

  Widget _celulaDia(int dia, int quantidade) {
    final tema = Theme.of(context);
    final ehHoje = mesmoDia(DateTime(_data.year, _data.month, dia), DateTime.now());
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        _data = DateTime(_data.year, _data.month, dia);
        _periodo = _Periodo.dia;
      }),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ehHoje ? tema.colorScheme.primary : tema.colorScheme.outlineVariant,
            width: ehHoje ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dia', style: tema.textTheme.labelLarge),
            const Spacer(),
            if (quantidade > 0)
              Align(
                alignment: Alignment.bottomRight,
                child: Badge(label: Text('$quantidade')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grade(List<Agendamento> doMes) {
    final tema = Theme.of(context);
    final primeiro = DateTime(_data.year, _data.month, 1);
    final totalDias = DateTime(_data.year, _data.month + 1, 0).day;
    final vazios = primeiro.weekday - 1;
    final contagem = <int, int>{};
    for (final a in doMes) {
      contagem[a.inicio.day] = (contagem[a.inicio.day] ?? 0) + 1;
    }
    const cabecalho = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Column(
      children: [
        Row(
          children: [
            for (final n in cabecalho)
              Expanded(
                child: Center(child: Text(n, style: tema.textTheme.labelMedium)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.2,
          children: [
            for (var i = 0; i < vazios; i++) const SizedBox.shrink(),
            for (var dia = 1; dia <= totalDias; dia++)
              _celulaDia(dia, contagem[dia] ?? 0),
          ],
        ),
      ],
    );
  }

  // ---------- corpo por estado ----------

  Widget _erro(String mensagem) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(mensagem),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<AgendamentoCubit>().carregar(),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }

  /// Aplica os filtros de TELA (sala/profissional/período) sobre as consultas
  /// que o Cubit já entregou filtradas pelo perfil (RN03).
  Widget _sucesso(
    List<Agendamento> consultas,
    Usuario usuario,
    bool global,
    String profId,
  ) {
    var lista = consultas;
    if (global && _visao == _Visao.sala) {
      lista = lista.where((a) => a.salaNumero == _salaFiltro).toList();
    }
    if (global && _visao == _Visao.profissional) {
      lista = lista.where((a) => a.profissionalId == profId).toList();
    }
    final ini = _inicioPeriodo;
    final fim = _fimPeriodo;
    lista = lista
        .where((a) => !a.inicio.isBefore(ini) && a.inicio.isBefore(fim))
        .toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));

    if (_periodo == _Periodo.mes) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: _grade(lista),
      );
    }
    return _listaDeAgendamentos(lista, usuario);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final global = politicaAcesso.podeVerAgendaGlobal(usuario);
    final podeAgendar = politicaAcesso.podeAgendar(usuario);
    final profissionais = auth.profissionaisSaude;
    final profId = _profFiltro ?? profissionais.first.id;

    // `pacientes` ainda é um ChangeNotifier: os nomes na lista dependem dele.
    return ListenableBuilder(
      listenable: pacientes,
      builder: (context, _) => BlocBuilder<AgendamentoCubit, AgendamentoState>(
        builder: (context, state) => Scaffold(
          floatingActionButton: podeAgendar
              ? FloatingActionButton.extended(
                  onPressed: () => _abrirForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo agendamento'),
                )
              : null,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  _cabecalho(global, profissionais, profId),
                  Expanded(
                    child: switch (state) {
                      AgendamentoInitial() || AgendamentoLoading() =>
                        const Center(child: CircularProgressIndicator()),
                      AgendamentoError(:final mensagem) => _erro(mensagem),
                      AgendamentoSuccess(:final consultas) =>
                        _sucesso(consultas, usuario, global, profId),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}