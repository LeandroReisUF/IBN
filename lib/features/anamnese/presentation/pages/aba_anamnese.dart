import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/anamnese/data/anamnese_repository.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';
import 'package:ibn/features/anamnese/presentation/cubit/anamnese_cubit.dart';
import 'package:ibn/features/anamnese/presentation/cubit/anamnese_state.dart';
import 'package:ibn/features/anamnese/presentation/widgets/formulario_anamnese.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

/// Anamnese configurável (RF03.3). Esta classe só **fornece** o Cubit.
class AbaAnamnese extends StatelessWidget {
  final Paciente paciente;
  const AbaAnamnese({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AnamneseCubit(
        repositorio: anamneseRepository,
        prontuario: prontuarioRepository,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
      )..carregar(),
      child: _AnamneseView(paciente: paciente),
    );
  }
}

/// O que o formulário devolve: as respostas e se é para assinar.
class _ResultadoForm {
  final Map<String, String> respostas;
  final bool assinar;
  const _ResultadoForm(this.respostas, this.assinar);
}

class _AnamneseView extends StatefulWidget {
  final Paciente paciente;
  const _AnamneseView({required this.paciente});

  @override
  State<_AnamneseView> createState() => _AnamneseViewState();
}

class _AnamneseViewState extends State<_AnamneseView> {
  bool get _podeEditar =>
      politicaAcesso.podeEditarAnamnese(auth.usuarioLogado!, widget.paciente);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<_ResultadoForm?> _abrirFormulario({
    required String titulo,
    required List<PerguntaAnamnese> perguntas,
    Map<String, String> respostas = const {},
  }) {
    return Navigator.of(context).push<_ResultadoForm>(
      MaterialPageRoute(
        builder: (_) => _PaginaFormulario(
          titulo: titulo,
          perguntas: perguntas,
          respostasIniciais: respostas,
        ),
      ),
    );
  }

  // ---------- ações ----------

  Future<void> _nova(List<ModeloAnamnese> modelos) async {
    final cubit = context.read<AnamneseCubit>();
    final modelo = modelos.length == 1
        ? modelos.first
        : await showDialog<ModeloAnamnese>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Escolha o modelo'),
              children: [
                for (final m in modelos)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(ctx).pop(m),
                    child: Text(m.nome),
                  ),
              ],
            ),
          );
    if (modelo == null || !mounted) return;
    final r = await _abrirFormulario(titulo: modelo.nome, perguntas: modelo.perguntas);
    if (r == null || !mounted) return;
    final erro = await cubit.salvar(modelo, r.respostas, assinar: r.assinar);
    if (!mounted) return;
    _aviso(erro ?? (r.assinar ? 'Anamnese assinada.' : 'Rascunho salvo.'));
  }

  /// Nova versão de uma anamnese assinada, já com as respostas anteriores.
  Future<void> _atualizar(Anamnese anterior, List<ModeloAnamnese> modelos) async {
    final cubit = context.read<AnamneseCubit>();
    ModeloAnamnese? modelo;
    for (final m in modelos) {
      if (m.id == anterior.modeloId) modelo = m;
    }
    if (modelo == null) {
      _aviso('O modelo desta anamnese não está mais disponível.');
      return;
    }
    final r = await _abrirFormulario(
      titulo: '${modelo.nome} (nova versão)',
      perguntas: modelo.perguntas,
      respostas: anterior.respostas,
    );
    if (r == null || !mounted) return;
    final erro = await cubit.salvar(modelo, r.respostas, anterior: anterior, assinar: r.assinar);
    if (!mounted) return;
    _aviso(erro ?? (r.assinar ? 'Nova versão assinada.' : 'Rascunho da nova versão salvo.'));
  }

  Future<void> _continuar(Anamnese a) async {
    final cubit = context.read<AnamneseCubit>();
    final r = await _abrirFormulario(
      titulo: a.titulo,
      perguntas: a.perguntas,
      respostas: a.respostas,
    );
    if (r == null || !mounted) return;
    final erro = await cubit.atualizarRascunho(a, r.respostas, assinar: r.assinar);
    if (!mounted) return;
    _aviso(erro ?? (r.assinar ? 'Anamnese assinada.' : 'Rascunho salvo.'));
  }

  Future<void> _descartar(Anamnese a) async {
    final cubit = context.read<AnamneseCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar rascunho?'),
        content: const Text('Só rascunhos podem ser descartados. Anamneses assinadas nunca são apagadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Descartar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final erro = await cubit.descartarRascunho(a);
    if (!mounted) return;
    if (erro != null) _aviso(erro);
  }

  // ---------- visual ----------

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  Widget _cartao(Anamnese a, bool substituida, List<ModeloAnamnese> modelos) {
    final tema = Theme.of(context);
    final minha = a.profissionalId == auth.usuarioLogado!.id;
    final autor = auth.buscarPorId(a.profissionalId)?.nome ?? 'profissional';
    final respondidas = [
      for (final p in a.perguntas)
        if (respostaLegivel(p, a.respostas[p.id]) != null) (p, respostaLegivel(p, a.respostas[p.id])!),
    ];
    final riscado = substituida ? const TextStyle(decoration: TextDecoration.lineThrough) : null;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: !a.assinada,
        title: Text('${a.titulo} • modelo v${a.modeloVersao}', style: riscado),
        subtitle: Text(
          '${_dataHora(a.criadaEm)}'
          '${a.assinada ? ' • assinada • selo ${a.selo}' : ' • rascunho'}'
          '${a.anteriorId == null ? '' : ' • atualiza uma versão anterior'}'
          '${minha ? '' : ' • por $autor'}',
        ),
        trailing: substituida ? const Chip(label: Text('Substituída')) : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (respondidas.isEmpty)
            const Text('Nenhuma pergunta respondida ainda.')
          else
            for (final (p, resposta) in respondidas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${p.enunciado}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: resposta, style: riscado),
                  ]),
                  style: tema.textTheme.bodyMedium,
                ),
              ),
                if (_podeEditar && minha) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!a.assinada) ...[
                  FilledButton.tonal(onPressed: () => _continuar(a), child: const Text('Continuar editando')),
                  TextButton(onPressed: () => _descartar(a), child: const Text('Descartar')),
                ],
                if (a.assinada && !substituida)
                  OutlinedButton.icon(
                    onPressed: () => _atualizar(a, modelos),
                    icon: const Icon(Icons.update),
                    label: const Text('Atualizar (nova versão)'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _conteudo(AnamneseSuccess s) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Anamnese', style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Você vê as suas anamneses e as ASSINADAS de colegas da mesma especialidade '
                  '(rascunhos e o modelo geral não são compartilhados). '
                  'só assina com as perguntas obrigatórias (*) respondidas. Depois de assinada '
                  'não muda (RN05): use Atualizar para criar uma nova versão e manter o histórico. '
                  'As perguntas dos modelos devem ser validadas pelos profissionais da clínica.',
                  style: tema.textTheme.bodySmall,
                ),
                if (_podeEditar && s.modelos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _nova(s.modelos),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova anamnese'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (s.anamneses.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhuma anamnese registrada.')),
          )
        else
          for (final a in s.anamneses) _cartao(a, s.substituidas.contains(a.id), s.modelos),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnamneseCubit, AnamneseState>(
      builder: (context, state) => switch (state) {
        AnamneseInitial() || AnamneseLoading() => const Center(child: CircularProgressIndicator()),
        AnamneseError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<AnamneseCubit>().carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        final AnamneseSuccess s => _conteudo(s),
      },
    );
  }
}

/// Página do formulário (rola bem em celular). Devolve null se cancelar.
class _PaginaFormulario extends StatefulWidget {
  final String titulo;
  final List<PerguntaAnamnese> perguntas;
  final Map<String, String> respostasIniciais;

  const _PaginaFormulario({
    required this.titulo,
    required this.perguntas,
    required this.respostasIniciais,
  });

  @override
  State<_PaginaFormulario> createState() => _PaginaFormularioState();
}

class _PaginaFormularioState extends State<_PaginaFormulario> {
  late Map<String, String> _respostas = Map.of(widget.respostasIniciais);

  List<String> get _faltando => faltandoObrigatorias(widget.perguntas, _respostas);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final faltando = _faltando;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormularioAnamnese(
                perguntas: widget.perguntas,
                respostasIniciais: widget.respostasIniciais,
                aoAlterar: (r) => setState(() => _respostas = r),
              ),
              if (faltando.isNotEmpty)
                Text(
                  'Para assinar, responda: ${faltando.join('; ')}.',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_ResultadoForm(_respostas, false)),
                    child: const Text('Salvar rascunho'),
                  ),
                  FilledButton(
                    onPressed: faltando.isEmpty
                        ? () => Navigator.of(context).pop(_ResultadoForm(_respostas, true))
                        : null,
                    child: const Text('Salvar e assinar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}