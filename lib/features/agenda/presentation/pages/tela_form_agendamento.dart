import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/features/agenda/presentation/cubit/agendamento_cubit.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/paciente_repository.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/core/politica_acesso_service.dart';


/// Criar / editar agendamento (RF02.1) com validação de conflitos ao vivo.
class TelaFormAgendamento extends StatefulWidget {
  final Agendamento? agendamento; // null = novo
  final DateTime dataInicial;
  final String? pacienteIdInicial;
  final String? procedimentoIdInicial;
  final String? profissionalIdInicial;

  const TelaFormAgendamento({
    super.key,
    this.agendamento,
    required this.dataInicial,
    this.pacienteIdInicial,
    this.procedimentoIdInicial,
    this.profissionalIdInicial,
  });

  @override
  State<TelaFormAgendamento> createState() => _TelaFormAgendamentoState();
}

class _TelaFormAgendamentoState extends State<TelaFormAgendamento> {
  final _formKey = GlobalKey<FormState>();
  final _dataCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _duracaoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  String? _pacienteId;
  Perfil? _tipo; // passo 1: tipo de profissional
  String? _procedimentoId;
  String? _profissionalId;
  int? _salaNumero;
  late DateTime _data;
  TimeOfDay? _hora;

  bool get _editando => widget.agendamento != null;

  /// Quem não é Recepção/Admin só agenda retorno dos próprios pacientes.
  bool get _restrito => !politicaAcesso.podeAgendar(auth.usuarioLogado!);

  Procedimento? get _proc =>
      _procedimentoId == null ? null : buscarProcedimento(_procedimentoId!);

  /// Passo 1: tipos de profissional que existem na clínica.
  List<Perfil> get _tiposDisponiveis => Perfil.values
      .where((p) => auth.profissionaisSaude.any((u) => u.perfil == p))
      .where((p) => !_restrito || p == auth.usuarioLogado!.perfil)
      .toList();
  /// Passo 2: só os procedimentos do tipo escolhido (lista curta).
  List<Procedimento> get _procedimentosDoTipo {
    final t = _tipo;
    if (t == null) return const [];
    return procedimentos
        .where((p) => t.especialidades.contains(p.especialidade))
        .toList();
  }

  /// Só as pessoas do tipo escolhido (ex.: Dr. Davi e Dra. Lúcia para Dentista).
  List<Usuario> get _profissionaisAptos {
    final t = _tipo;
    if (t == null) return const [];
    return auth.profissionaisSaude
        .where((u) => u.perfil == t && (!_restrito || u.id == auth.usuarioLogado!.id))
        .toList();
  }

  /// Só aparecem salas que aceitam a especialidade (RN01).
  List<Sala> get _salasAptas {
    final p = _proc;
    if (p == null) return const [];
    return salas.where((s) => s.permiteEspecialidade(p.especialidade)).toList();
  }

  String _fmtHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final a = widget.agendamento;
    if (a != null) {
      _pacienteId = a.pacienteId;
      _tipo = auth.buscarPorId(a.profissionalId)?.perfil;
      _procedimentoId = a.procedimentoId;
      _profissionalId = a.profissionalId;
      _salaNumero = a.salaNumero;
      _data = soData(a.inicio);
      _hora = TimeOfDay(hour: a.inicio.hour, minute: a.inicio.minute);
      _duracaoCtrl.text = a.fim.difference(a.inicio).inMinutes.toString();
      _obsCtrl.text = a.observacoes;
        } else {
      _data = widget.dataInicial;
      _pacienteId = widget.pacienteIdInicial;
      final prof = widget.profissionalIdInicial == null
          ? null
          : auth.buscarPorId(widget.profissionalIdInicial!);
      if (prof != null) {
        _tipo = prof.perfil;
        _profissionalId = prof.id;
      }
      final proc = widget.procedimentoIdInicial == null
          ? null
          : buscarProcedimento(widget.procedimentoIdInicial!);
      if (proc != null && (_tipo?.especialidades.contains(proc.especialidade) ?? false)) {
        _procedimentoId = proc.id;
        _duracaoCtrl.text = proc.duracaoMinutos.toString();
        final aptas = _salasAptas;
        if (aptas.length == 1) _salaNumero = aptas.first.numero; // Sala 3 (RN01)
      }
    }
    _dataCtrl.text = formatarData(_data);
    _horaCtrl.text = _hora == null ? '' : _fmtHora(_hora!);
    _duracaoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dataCtrl.dispose();
    _horaCtrl.dispose();
    _duracaoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  // ---------- ações ----------

  void _aoEscolherTipo(Perfil? tipo) {
    _duracaoCtrl.clear();
    setState(() {
      _tipo = tipo;
      _procedimentoId = null;
      _salaNumero = null;
      final profs = _profissionaisAptos;
      _profissionalId = profs.length == 1 ? profs.first.id : null;
    });
    // Se o tipo tem um único procedimento, ele já vem escolhido.
    final procs = _procedimentosDoTipo;
    if (procs.length == 1) _aoEscolherProcedimento(procs.first.id);
  }

  void _aoEscolherProcedimento(String? id) {
    final proc = id == null ? null : buscarProcedimento(id);
    if (proc != null) _duracaoCtrl.text = proc.duracaoMinutos.toString();
    setState(() {
      _procedimentoId = id;
      final aptas = _salasAptas;
      if (!aptas.any((s) => s.numero == _salaNumero)) {
        // Salas exclusivas (3 e 4) têm só uma opção: já vem escolhida.
        _salaNumero = aptas.length == 1 ? aptas.first.numero : null;
      }
    });
  }

  Future<void> _escolherData() async {
    final nova = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nova == null) return;
    setState(() {
      _data = soData(nova);
      _dataCtrl.text = formatarData(_data);
    });
  }

  Future<void> _escolherHora() async {
    final nova = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (nova == null) return;
    setState(() {
      _hora = nova;
      _horaCtrl.text = _fmtHora(nova);
    });
  }

  Agendamento? _montar({required String id}) {
    if (_pacienteId == null ||
        _procedimentoId == null ||
        _profissionalId == null ||
        _salaNumero == null ||
        _hora == null) {
      return null;
    }
    final minutos = int.tryParse(_duracaoCtrl.text);
    if (minutos == null || minutos < 5) return null;
    final inicio = DateTime(_data.year, _data.month, _data.day, _hora!.hour, _hora!.minute);
    return Agendamento(
      id: id,
      pacienteId: _pacienteId!,
      profissionalId: _profissionalId!,
      salaNumero: _salaNumero!,
      procedimentoId: _procedimentoId!,
      inicio: inicio,
      fim: inicio.add(Duration(minutes: minutos)),
      status: widget.agendamento?.status ?? StatusAgendamento.agendado,
      observacoes: _obsCtrl.text.trim(),
    );
  }

    Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<AgendamentoCubit>();
    final ag = _montar(id: widget.agendamento?.id ?? cubit.novoId());
    if (ag == null) return;

    final mensagem = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    if (_restrito) {
      final usuario = auth.usuarioLogado!;
      final p = pacientes.buscarPorId(ag.pacienteId);
      if (p == null ||
          ag.profissionalId != usuario.id ||
          !politicaAcesso.podeAgendarRetorno(usuario, p)) {
        mensagem.showSnackBar(
          const SnackBar(content: Text('Você só pode agendar retorno dos seus pacientes, para você mesmo.')),
        );
        return;
      }
    }

    final erro = _editando ? await cubit.atualizar(ag) : await cubit.criar(ag);
    if (!mounted) return;
    if (erro != null) {
      mensagem.showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    navegador.pop();
    mensagem.showSnackBar(
      SnackBar(content: Text(_editando ? 'Agendamento atualizado.' : 'Agendamento criado.')),
    );
  }

  // ---------- visual ----------

  InputDecoration _decoracao(String rotulo, IconData icone, {String? ajuda}) =>
      InputDecoration(
        labelText: rotulo,
        helperText: ajuda,
        prefixIcon: Icon(icone),
        border: const OutlineInputBorder(),
      );

  Widget _linha(List<Widget> campos, double largura) {
    final colunas = largura >= 600 ? campos.length : 1;
    final larguraCampo = (largura - 16 * (colunas - 1)) / colunas;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final c in campos) SizedBox(width: larguraCampo, child: c),
      ],
    );
  }

  Widget _previa(ColorScheme cores) {
    final ag = _montar(id: widget.agendamento?.id ?? 'previa');
    if (ag == null) return const SizedBox.shrink();
    final erro = context.read<AgendamentoCubit>().validarConflitos(ag);
    final ok = erro == null;
    return Card(
      color: ok ? Colors.green.withValues(alpha: 0.12) : cores.errorContainer,
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          color: ok ? Colors.green : cores.error,
        ),
        title: Text(ok ? 'Horário disponível: sala e profissional livres.' : erro),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
        final pacientesLista = pacientes.todos
        .where((p) => p.ativo || p.id == _pacienteId)
        .where((p) => !_restrito || politicaAcesso.podeAgendarRetorno(auth.usuarioLogado!, p))
        .toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final profs = _profissionaisAptos;
    final salasAptas = _salasAptas;
    final tipos = _tiposDisponiveis;
    final procs = _procedimentosDoTipo;
    final multiEspecialidade = (_tipo?.especialidades.length ?? 0) > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar agendamento' : 'Novo agendamento'),
        actions: [
          TextButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.check),
            label: const Text('Salvar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, restricoes) {
          final largura = (restricoes.maxWidth - 48).clamp(0.0, 800.0).toDouble();
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: largura,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _pacienteId,
                        isExpanded: true,
                        decoration: _decoracao('Paciente', Icons.person_outline),
                        items: [
                          for (final p in pacientesLista)
                            DropdownMenuItem(value: p.id, child: Text(p.nome)),
                        ],
                        onChanged: (v) => setState(() => _pacienteId = v),
                        validator: (v) => v == null ? 'Selecione o paciente' : null,
                      ),
                      const SizedBox(height: 16),
                      _linha([
                        DropdownButtonFormField<Perfil>(
                          initialValue: _tipo,
                          isExpanded: true,
                          decoration: _decoracao('Tipo de profissional', Icons.groups_outlined),
                          items: [
                            for (final t in tipos)
                              DropdownMenuItem(value: t, child: Text(t.rotulo)),
                          ],
                          onChanged: _aoEscolherTipo,
                          validator: (v) =>
                              v == null ? 'Selecione o tipo de profissional' : null,
                        ),
                        DropdownButtonFormField<String>(
                          key: ValueKey('proc-${_tipo?.name}'),
                          initialValue: _procedimentoId,
                          isExpanded: true,
                          decoration: _decoracao(
                            'Procedimento',
                            Icons.medical_services_outlined,
                            ajuda: _tipo == null
                                ? 'Escolha o tipo de profissional primeiro'
                                : null,
                          ),
                          items: [
                            for (final p in procs)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text(multiEspecialidade
                                    ? '${p.nome} (${p.especialidade.rotulo})'
                                    : p.nome),
                              ),
                          ],
                          onChanged: procs.isEmpty ? null : _aoEscolherProcedimento,
                          validator: (v) => v == null ? 'Selecione o procedimento' : null,
                        ),
                      ], largura),
                      const SizedBox(height: 16),
                      _linha([
                        DropdownButtonFormField<String>(
                          key: ValueKey('prof-${_tipo?.name}'),
                          initialValue: _profissionalId,
                          isExpanded: true,
                          decoration: _decoracao(
                            'Profissional',
                            Icons.badge_outlined,
                            ajuda: _tipo == null ? 'Escolha o tipo de profissional primeiro' : null,
                          ),
                          items: [
                            for (final u in profs)
                              DropdownMenuItem(value: u.id, child: Text(u.nome)),
                          ],
                          onChanged: profs.isEmpty
                              ? null
                              : (v) => setState(() => _profissionalId = v),
                          validator: (v) => v == null ? 'Selecione o profissional' : null,
                        ),
                        DropdownButtonFormField<int>(
                          key: ValueKey('sala-$_procedimentoId'),
                          initialValue: _salaNumero,
                          isExpanded: true,
                          decoration: _decoracao(
                            'Sala',
                            Icons.meeting_room_outlined,
                            ajuda: 'Sala 3: Odontologia · Sala 4: Biomedicina',
                          ),
                          items: [
                            for (final s in salasAptas)
                              DropdownMenuItem(value: s.numero, child: Text(s.nome)),
                          ],
                          onChanged: salasAptas.isEmpty
                              ? null
                              : (v) => setState(() => _salaNumero = v),
                          validator: (v) => v == null ? 'Selecione a sala' : null,
                        ),
                      ], largura),
                      const SizedBox(height: 16),
                      _linha([
                        TextFormField(
                          controller: _dataCtrl,
                          readOnly: true,
                          onTap: _escolherData,
                          decoration: _decoracao('Data', Icons.event_outlined),
                        ),
                        TextFormField(
                          controller: _horaCtrl,
                          readOnly: true,
                          onTap: _escolherHora,
                          decoration: _decoracao('Início', Icons.schedule_outlined),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Escolha o horário' : null,
                        ),
                        TextFormField(
                          controller: _duracaoCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _decoracao('Duração (min)', Icons.timer_outlined),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 5 || n > 480) return 'Entre 5 e 480';
                            return null;
                          },
                        ),
                      ], largura),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _obsCtrl,
                        maxLines: 3,
                        decoration: _decoracao('Observações (opcional)', Icons.notes_outlined),
                      ),
                      const SizedBox(height: 16),
                      _previa(tema.colorScheme),
                      if (!_editando)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Ao salvar, o paciente é vinculado automaticamente ao profissional escolhido.',
                            style: tema.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}