import 'package:flutter/foundation.dart';
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

/// Anamnese como aba própria (usada pela Biomedicina): só envolve o conteúdo
/// em uma área rolável. O conteúdo está em [AnamneseInline].
class AbaAnamnese extends StatelessWidget {
  final Paciente paciente;
  const AbaAnamnese({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: AnamneseInline(paciente: paciente),
        ),
      ),
    );
  }
}

/// Anamnese sempre aberta para preencher, com um único botão "Salvar anamnese"
/// (RF03.3). Não rola sozinha: quem a usa fornece a rolagem. Esta classe só
/// **fornece** o Cubit.
class AnamneseInline extends StatelessWidget {
  final Paciente paciente;
  const AnamneseInline({super.key, required this.paciente});

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

class _AnamneseView extends StatefulWidget {
  final Paciente paciente;
  const _AnamneseView({required this.paciente});

  @override
  State<_AnamneseView> createState() => _AnamneseViewState();
}

class _AnamneseViewState extends State<_AnamneseView> {
  final Key _chaveForm = UniqueKey();
  Map<String, String>? _respostas; // null = ainda não mexeu no formulário

  bool get _podeEditar =>
      politicaAcesso.podeEditarAnamnese(auth.usuarioLogado!, widget.paciente);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  /// O modelo da especialidade do usuário (o geral não aparece nesta tela).
  ModeloAnamnese? _modelo(AnamneseSuccess s) {
    if (s.modelos.isEmpty) return null;
    return s.modelos.firstWhere((m) => m.especialidade != null, orElse: () => s.modelos.first);
  }

  /// Minha versão mais recente deste modelo (a que ainda não foi substituída).
  Anamnese? _ultima(AnamneseSuccess s, ModeloAnamnese m) {
    final uid = auth.usuarioLogado!.id;
    return s.anamneses
        .where((a) =>
            a.profissionalId == uid && a.modeloId == m.id && !s.substituidas.contains(a.id))
        .firstOrNull;
  }

  /// Cada salvamento é uma nova versão assinada; a anterior fica no histórico (RN05).
  Future<void> _salvar(ModeloAnamnese m, Anamnese? ultima) async {
    final r = _respostas;
    if (r == null) return;
    final cubit = context.read<AnamneseCubit>();
    final String? erro;
    if (ultima != null && !ultima.assinada) {
      erro = await cubit.atualizarRascunho(ultima, r, assinar: true);
    } else {
      erro = await cubit.salvar(m, r, anterior: ultima, assinar: true);
    }
    if (!mounted) return;
    _aviso(erro ?? 'Anamnese salva.');
  }

  // ---------- visual ----------

  Widget _barra(ModeloAnamnese m, Anamnese? ultima, Map<String, String> atuais) {
    final tema = Theme.of(context);
    final mudou = _respostas != null &&
        !mapEquals(_respostas, ultima?.respostas ?? const <String, String>{});
    final faltando = faltandoObrigatorias(m.perguntas, atuais);
    final String status;
    if (faltando.isNotEmpty) {
      status = 'Para salvar, responda: ${faltando.join('; ')}.';
    } else if (mudou) {
      status = 'Alterações ainda não salvas.';
    } else if (ultima == null) {
      status = 'Nenhuma anamnese salva ainda.';
    } else {
      status = 'Salva em ${_dataHora(ultima.assinadaEm ?? ultima.criadaEm)}. Sem alterações desde então.';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: mudou && faltando.isEmpty ? () => _salvar(m, ultima) : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar anamnese'),
                ),
                Text(
                  status,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: faltando.isNotEmpty ? tema.colorScheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cada vez que você salva, uma nova versão é gravada; as anteriores ficam no '
              'histórico (RN05).',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _versao(Anamnese a, bool substituida) {
    final tema = Theme.of(context);
    final minha = a.profissionalId == auth.usuarioLogado!.id;
    final autor = auth.buscarPorId(a.profissionalId)?.nome ?? 'profissional';
    final respondidas = [
      for (final p in a.perguntas)
        if (respostaLegivel(p, a.respostas[p.id]) != null)
          (p, respostaLegivel(p, a.respostas[p.id])!),
    ];
    final riscado = substituida ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    return ExpansionTile(
      key: ValueKey('versao-${a.id}'),
      title: Text('${_dataHora(a.criadaEm)}${minha ? '' : ' • por $autor'}', style: riscado),
      subtitle: Text(
        '${a.assinada ? 'assinada • selo ${a.selo}' : 'rascunho'} • modelo v${a.modeloVersao}'
        '${a.anteriorId == null ? '' : ' • atualiza uma versão anterior'}',
      ),
      trailing: substituida ? const Chip(label: Text('Substituída')) : null,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (respondidas.isEmpty)
          const Text('Nenhuma pergunta respondida.')
        else
          for (final (p, resposta) in respondidas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${p.enunciado}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: resposta, style: riscado),
                ]),
                style: tema.textTheme.bodyMedium,
              ),
            ),
      ],
    );
  }

  Widget _historico(AnamneseSuccess s) {
    if (s.anamneses.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        key: const ValueKey('historico-anamnese'),
        title: const Text('Histórico de versões'),
        subtitle: Text(
          '${s.anamneses.length} registro(s); inclui as assinadas de colegas da mesma '
          'especialidade (somente leitura)',
        ),
        childrenPadding: const EdgeInsets.only(left: 8),
        children: [for (final a in s.anamneses) _versao(a, s.substituidas.contains(a.id))],
      ),
    );
  }

  Widget _conteudo(AnamneseSuccess s) {
    final m = _modelo(s);
    if (m == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nenhum modelo de anamnese disponível para o seu perfil.'),
      );
    }
    final ultima = _ultima(s, m);
    final atuais = _respostas ?? ultima?.respostas ?? const <String, String>{};

    Widget form = FormularioAnamnese(
      key: _chaveForm,
      perguntas: m.perguntas,
      respostasIniciais: ultima?.respostas ?? const {},
      aoAlterar: (r) => setState(() => _respostas = r),
    );
    // Modelo sem seções (ex.: estética): o formulário vai dentro de um cartão.
    if (!m.perguntas.any((p) => p.secao != null)) {
      form = Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.nome, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              form,
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AbsorbPointer(absorbing: !_podeEditar, child: form),
        if (_podeEditar) ...[const SizedBox(height: 8), _barra(m, ultima, atuais)],
        const SizedBox(height: 8),
        _historico(s),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnamneseCubit, AnamneseState>(
      builder: (context, state) => switch (state) {
        AnamneseInitial() || AnamneseLoading() => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
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